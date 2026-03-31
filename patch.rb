#!/usr/bin/ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'

ENTRY_HEADER = "\x10\x00\x00\x00\x00\x00\x00\x00\x09\x00\x00\x00".b
FIRST_VERB = "Accomplishing".b

def find_binary
  dirs = [
    File.expand_path("~/.local/share/claude/versions"),
    File.expand_path("~/.claude/versions")
  ]

  dirs.each do |dir|
    next unless Dir.exist?(dir)
    entries = Dir.entries(dir)
      .reject { |f| f.start_with?('.') || f.end_with?('.backup') }
      .map { |f| File.join(dir, f) }
      .select { |f| File.file?(f) && File.executable?(f) }
      .sort_by { |f| -File.mtime(f).to_i }

    return entries.first unless entries.empty?
  end

  claude = `which claude 2>/dev/null`.strip
  return File.realpath(claude) if !claude.empty? && File.file?(claude)

  nil
end

def load_verbs(path)
  verbs = JSON.parse(File.read(path))
  abort "verbs.json must be a non-empty array" unless verbs.is_a?(Array) && !verbs.empty?
  verbs
end

def find_verb_arrays(data)
  arrays = []
  pos = 0
  while (idx = data.index(FIRST_VERB, pos))
    header_start = idx - 16
    if header_start >= 0 && data[header_start, 12] == ENTRY_HEADER
      arrays << header_start
    end
    pos = idx + FIRST_VERB.size
  end
  arrays
end

def find_any_verb_array(data)
  hits = []
  probes = %w[Boondoggling Flibbertigibbeting Razzmatazzing Prestidigitating
              Discombobulating Whatchamacalliting Shenaniganing Hullaballooing
              Ogarnianie Pierdolenie Kminienie Kombinowanie
              Procrastinating Overthinking Doom-scrolling
              Synergizing Solutioning Squatting Deadlifting
              Chopping Deglazing]
  probes.each do |verb|
    vb = verb.b
    pos = 0
    while (idx = data.index(vb, pos))
      hs = idx - 16
      if hs >= 0 && data[hs, 8] == "\x10\x00\x00\x00\x00\x00\x00\x00".b
        str_len = data[hs + 12, 4].unpack1('V')
        hits << hs if str_len == vb.size
      end
      pos = idx + vb.size
    end
  end
  return [] if hits.empty?

  hits.sort!
  hits.uniq!

  groups = hits.slice_when { |a, b| b - a > 100_000 }.to_a

  groups.map do |group|
    earliest = group.min
    scan = earliest
    loop do
      found_prev = false
      64.step(16, -16) do |try_back|
        test = scan - try_back
        next if test < 0
        next unless data[test, 8] == "\x10\x00\x00\x00\x00\x00\x00\x00".b
        tl = data[test + 12, 4].unpack1('V')
        next unless tl >= 3 && tl <= 30
        tp = ((tl + 15) / 16) * 16
        if test + 16 + tp == scan
          scan = test
          found_prev = true
          break
        end
      end
      break unless found_prev
    end
    scan
  end.uniq.select { |r| count_entries(data, r) >= 50 }
end

def count_entries(data, start)
  limit = start + 9_000
  pos = start
  count = 0
  while (pos = skip_to_entry(data, pos, limit))
    str_len = data[pos + 12, 4].unpack1('V')
    padded = ((str_len + 15) / 16) * 16
    count += 1
    pos += 16 + padded
  end
  count
end

def skip_to_entry(data, pos, limit)
  while pos < limit
    if data[pos, 8] == "\x10\x00\x00\x00\x00\x00\x00\x00".b
      str_len = data[pos + 12, 4].unpack1('V')
      return pos if str_len >= 3 && str_len <= 30
    end
    pos += 16
  end
  nil
end

def read_array(data, start)
  verbs = []
  limit = start + 9_000
  pos = start
  while (pos = skip_to_entry(data, pos, limit))
    str_len = data[pos + 12, 4].unpack1('V')
    padded = ((str_len + 15) / 16) * 16
    verbs << data[pos + 16, str_len].force_encoding('UTF-8')
    pos += 16 + padded
  end
  verbs
end

def patch_array(data, start, verbs)
  limit = start + 9_000
  pos = start
  patched = 0
  verb_idx = 0

  while (pos = skip_to_entry(data, pos, limit))
    str_len = data[pos + 12, 4].unpack1('V')
    padded = ((str_len + 15) / 16) * 16
    slot_size = 16 + padded

    fits = verbs.select { |v| v.encode('UTF-8').bytesize <= padded }
    if fits.empty?
      verb_idx += 1
      pos += slot_size
      next
    end

    new_str = fits[verb_idx % fits.size]
    new_bytes = new_str.encode('UTF-8')
    new_len = new_bytes.bytesize

    data[pos + 12, 4] = [new_len].pack('V')

    padded.times do |i|
      data.setbyte(pos + 16 + i, i < new_len ? new_bytes.getbyte(i) : 0)
    end

    patched += 1
    verb_idx += 1
    pos += slot_size
  end

  patched
end

def extract_entitlements(binary)
  path = File.join(ENV['TMPDIR'] || '/tmp', "dzialaj-ent-#{$$}.plist")
  system("codesign", "-d", "--entitlements", path, "--xml", binary,
         out: File::NULL, err: File::NULL)

  if !File.exist?(path) || File.size(path) == 0
    File.write(path, <<~PLIST)
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0"><dict>
      <key>com.apple.security.cs.allow-jit</key><true/>
      <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
      <key>com.apple.security.cs.disable-library-validation</key><true/>
      </dict></plist>
    PLIST
  end

  path
end

def resign(binary, entitlements)
  system("codesign", "--remove-signature", binary, err: File::NULL)
  system("codesign", "-f", "-s", "-", "--entitlements", entitlements,
         "--options", "runtime", binary)
end

def cmd_patch(verbs_file)
  binary = find_binary
  abort "Could not find Claude Code binary." unless binary
  puts "Binary: #{binary}"

  backup = "#{binary}.backup"
  if File.exist?(backup)
    puts "Backup: #{backup} (exists)"
  else
    puts "Backup: #{backup}"
    FileUtils.cp(binary, backup, preserve: true)
  end

  verbs = load_verbs(verbs_file)
  puts "Loaded #{verbs.size} verbs"

  entitlements = extract_entitlements(binary) if RUBY_PLATFORM.include?('darwin')

  data = File.binread(binary).dup
  data.force_encoding('BINARY')

  arrays = find_verb_arrays(data)
  abort "Could not find verb arrays. Is this Claude Code >= 2.x?" if arrays.empty?
  puts "Found #{arrays.size} verb array(s)"

  total = 0
  arrays.each_with_index do |offset, i|
    count = patch_array(data, offset, verbs)
    puts "  Array #{i}: #{count} verbs patched"
    total += count
  end

  File.binwrite(binary, data)

  if RUBY_PLATFORM.include?('darwin') && entitlements
    puts "Re-signing binary (macOS)..."
    unless resign(binary, entitlements)
      puts "Signing failed! Restoring backup..."
      FileUtils.cp(backup, binary, preserve: true)
      exit 1
    end
    puts "Signed OK"
    File.delete(entitlements) rescue nil
  end

  puts "\nDone! #{total} verbs patched."
  puts "Restore: ruby patch.rb --restore"
end

def cmd_restore
  binary = find_binary
  abort "Could not find Claude Code binary." unless binary
  backup = "#{binary}.backup"
  abort "No backup found." unless File.exist?(backup)
  FileUtils.cp(backup, binary, preserve: true)
  puts "Restored: #{binary}"
end

def cmd_list
  binary = find_binary
  abort "Could not find Claude Code binary." unless binary

  data = File.binread(binary).b

  arrays = find_verb_arrays(data)
  arrays = find_any_verb_array(data) if arrays.empty?
  abort "No verb arrays found." if arrays.empty?

  read_array(data, arrays.first).each { |v| puts v }
end

def pick_pack
  script_dir = File.dirname(File.expand_path(__FILE__))
  verbs_dir = File.join(script_dir, 'verbs')
  packs = Dir.glob(File.join(verbs_dir, '*.json')).sort

  if packs.empty?
    abort "No verb packs found in #{verbs_dir}"
  end

  puts "Available packs:"
  packs.each_with_index do |p, i|
    name = File.basename(p, '.json')
    verbs = JSON.parse(File.read(p))
    sample = verbs.first(3).join(', ')
    puts "  #{i + 1}) #{name} (#{verbs.size} verbs: #{sample}...)"
  end

  print "\nPick a pack [1-#{packs.size}]: "
  choice = $stdin.gets
  abort "Cancelled." unless choice
  choice = choice.strip.to_i
  abort "Invalid choice." unless choice >= 1 && choice <= packs.size

  packs[choice - 1]
end

# --- main ---

case ARGV[0]
when '--restore'
  cmd_restore
when '--list'
  cmd_list
else
  if ARGV[0] && !ARGV[0].start_with?('-')
    verbs_file = ARGV[0]
    abort "File not found: #{verbs_file}" unless File.exist?(verbs_file)
  else
    verbs_file = pick_pack
  end
  cmd_patch(verbs_file)
end
