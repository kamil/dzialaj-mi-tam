#!/usr/bin/ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'

HEADER = "\x10\x00\x00\x00\x00\x00\x00\x00".b
HEADER_WITH_TYPE = "\x10\x00\x00\x00\x00\x00\x00\x00\x09\x00\x00\x00".b
FIRST_VERB = "Accomplishing".b
ARRAY_SCAN_LIMIT = 9_000

PROBES = %w[
  Boondoggling Flibbertigibbeting Razzmatazzing Prestidigitating
  Discombobulating Whatchamacalliting Shenaniganing Hullaballooing
  Ogarnianie Pierdolenie Kminienie Jeremiaszenie Augustynowanie
  Procrastinating Overthinking Synergizing Squatting Chopping
  Hallucinating Sycophanting Confabulating Benchmarking
].freeze

def find_binary
  dir = File.expand_path("~/.local/share/claude/versions")
  if Dir.exist?(dir)
    entry = Dir.entries(dir)
      .reject { |f| f.start_with?('.') || f.end_with?('.backup') }
      .map { |f| File.join(dir, f) }
      .select { |f| File.file?(f) && File.executable?(f) }
      .max_by { |f| File.mtime(f).to_i }
    return entry if entry
  end

  claude = `which claude 2>/dev/null`.strip
  File.realpath(claude) if !claude.empty? && File.file?(claude)
end

def load_verbs(path)
  verbs = JSON.parse(File.read(path))
  abort "verbs file must be a non-empty array" unless verbs.is_a?(Array) && !verbs.empty?
  verbs
end

def padded(len)
  ((len + 15) / 16) * 16
end

def skip_to_entry(data, pos, limit)
  while pos < limit
    if data[pos, 8] == HEADER
      str_len = data[pos + 12, 4].unpack1('V')
      return pos if str_len >= 3 && str_len <= 30
    end
    pos += 16
  end
  nil
end

def each_entry(data, start)
  limit = start + ARRAY_SCAN_LIMIT
  pos = start
  while (pos = skip_to_entry(data, pos, limit))
    str_len = data[pos + 12, 4].unpack1('V')
    pad = padded(str_len)
    yield pos, str_len, pad
    pos += 16 + pad
  end
end

def find_verb_arrays(data)
  arrays = []
  pos = 0
  while (idx = data.index(FIRST_VERB, pos))
    hs = idx - 16
    arrays << hs if hs >= 0 && data[hs, 12] == HEADER_WITH_TYPE
    pos = idx + FIRST_VERB.size
  end
  arrays
end

def find_any_verb_array(data)
  hits = []
  PROBES.each do |verb|
    vb = verb.encode('UTF-8').b
    pos = 0
    while (idx = data.index(vb, pos))
      hs = idx - 16
      if hs >= 0 && data[hs, 8] == HEADER
        str_len = data[hs + 12, 4].unpack1('V')
        hits << hs if str_len == vb.bytesize
      end
      pos = idx + vb.bytesize
    end
  end
  return [] if hits.empty?

  groups = hits.sort.uniq.slice_when { |a, b| b - a > 100_000 }.to_a
  groups.map { |g| walk_back(data, g.min) }
    .uniq
    .select { |r| count_entries(data, r) >= 50 }
end

def walk_back(data, pos)
  loop do
    found = false
    64.step(16, -16) do |tb|
      test = pos - tb
      next if test < 0
      next unless data[test, 8] == HEADER
      tl = data[test + 12, 4].unpack1('V')
      next unless tl >= 3 && tl <= 30
      if test + 16 + padded(tl) == pos
        pos = test
        found = true
        break
      end
    end
    break unless found
  end
  pos
end

def count_entries(data, start)
  n = 0
  each_entry(data, start) { n += 1 }
  n
end

def read_array(data, start)
  verbs = []
  each_entry(data, start) do |pos, str_len, _|
    verbs << data[pos + 16, str_len].force_encoding('UTF-8')
  end
  verbs
end

def patch_array(data, start, verbs)
  by_pad = {}
  verbs.each do |v|
    bs = v.encode('UTF-8').bytesize
    (padded(bs)..64).step(16) { |p| (by_pad[p] ||= []) << v }
  end

  patched = 0
  verb_idx = 0
  each_entry(data, start) do |pos, _, pad|
    fits = by_pad[pad]
    unless fits
      verb_idx += 1
      next
    end

    new_bytes = fits[verb_idx % fits.size].encode('UTF-8')
    new_len = new_bytes.bytesize

    data[pos + 12, 4] = [new_len].pack('V')
    pad.times { |i| data.setbyte(pos + 16 + i, i < new_len ? new_bytes.getbyte(i) : 0) }

    patched += 1
    verb_idx += 1
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
  system("codesign", "--remove-signature", binary, out: File::NULL, err: File::NULL)
  system("codesign", "-f", "-s", "-", "--entitlements", entitlements,
         "--options", "runtime", binary, out: File::NULL, err: File::NULL)
end

def cmd_patch(verbs_file)
  binary = find_binary
  abort "Could not find Claude Code binary." unless binary
  puts "Binary: #{binary}"

  backup = "#{binary}.backup"
  unless File.exist?(backup)
    FileUtils.cp(binary, backup, preserve: true)
    puts "Backup: #{backup}"
  end

  verbs = load_verbs(verbs_file)
  puts "Loaded #{verbs.size} verbs"

  entitlements = extract_entitlements(binary) if RUBY_PLATFORM.include?('darwin')

  data = File.binread(binary).dup
  data.force_encoding('BINARY')

  arrays = find_verb_arrays(data)
  abort "Could not find verb arrays. Is this Claude Code >= 2.x?" if arrays.empty?

  total = 0
  arrays.each_with_index do |offset, i|
    count = patch_array(data, offset, verbs)
    puts "  Array #{i}: #{count} verbs patched"
    total += count
  end

  File.binwrite(binary, data)

  if RUBY_PLATFORM.include?('darwin') && entitlements
    unless resign(binary, entitlements)
      puts "Signing failed, restoring backup..."
      FileUtils.cp(backup, binary, preserve: true)
      exit 1
    end
    File.delete(entitlements) rescue nil
  end

  puts "Done! #{total} verbs patched."
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
  verbs_dir = File.join(File.dirname(File.expand_path(__FILE__)), 'verbs')
  packs = Dir.glob(File.join(verbs_dir, '*.json')).sort

  abort "No verb packs found in #{verbs_dir}" if packs.empty?

  default_idx = packs.index { |p| File.basename(p, '.json') == 'ai-slop' }
  default_num = default_idx ? default_idx + 1 : 1

  puts "Available packs:"
  packs.each_with_index do |p, i|
    name = File.basename(p, '.json')
    sample = JSON.parse(File.read(p)).first(3).join(', ')
    marker = (i + 1 == default_num) ? " (default)" : ""
    puts "  #{i + 1}) #{name} - #{sample}...#{marker}"
  end

  print "\nPick [1-#{packs.size}] (enter for #{default_num}): "
  choice = $stdin.gets
  abort "Cancelled." unless choice
  input = choice.strip
  idx = input.empty? ? default_num : input.to_i
  abort "Invalid choice." unless idx >= 1 && idx <= packs.size
  packs[idx - 1]
end

case ARGV[0]
when '--restore' then cmd_restore
when '--list'    then cmd_list
else
  if ARGV[0] && !ARGV[0].start_with?('-')
    verbs_file = ARGV[0]
    abort "File not found: #{verbs_file}" unless File.exist?(verbs_file)
  else
    verbs_file = pick_pack
  end
  cmd_patch(verbs_file)
end
