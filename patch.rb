#!/usr/bin/ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'

ORIGINAL_MARKER = '=["Accomplishing","Actioning"'.b

KNOWN_VERBS = %w[
  Boondoggling Flibbertigibbeting Razzmatazzing Discombobulating
  Whatchamacalliting Shenaniganing Prestidigitating
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

def find_js_arrays(data)
  positions = []

  pos = 0
  while (idx = data.index(ORIGINAL_MARKER, pos))
    arr_start = idx + 1
    arr_end = data.index("]".b, arr_start)
    positions << [arr_start, arr_end] if arr_end
    pos = idx + ORIGINAL_MARKER.size
  end
  return positions unless positions.empty?

  pos = 0
  while (idx = data.index('=["'.b, pos))
    arr_start = idx + 1
    pos = idx + 3
    arr_end = data.index("]".b, arr_start + 500)
    next unless arr_end
    chunk = data[arr_start..arr_end]
    next if chunk.bytesize < 500 || chunk.bytesize > 5000
    begin
      parsed = JSON.parse(chunk.force_encoding('UTF-8'))
      next unless parsed.is_a?(Array) && parsed.size >= 50
      has_upper = parsed.count { |v| v.is_a?(String) && v[0] =~ /[A-Z]/ }
      next unless parsed.all? { |v| v.is_a?(String) && v.size >= 3 && v.size <= 40 }
      next unless has_upper > parsed.size / 2
      positions << [arr_start, arr_end]
    rescue
    end
  end

  positions.uniq
end

def read_js_array(data, arr_start, arr_end)
  JSON.parse(data[arr_start..arr_end].force_encoding('UTF-8'))
rescue
  []
end

def build_replacement(original_size, verbs)
  items = []
  verb_idx = 0
  1000.times do
    items << verbs[verb_idx % verbs.size]
    verb_idx += 1
    break if JSON.generate(items).bytesize >= original_size
  end
  items.pop if JSON.generate(items).bytesize > original_size

  result = JSON.generate(items)
  deficit = original_size - result.bytesize
  if deficit > 0
    result = result[0..-2] + (" " * deficit) + "]"
  end
  result[0, original_size]
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
  end

  verbs = load_verbs(verbs_file)
  puts "Loaded #{verbs.size} verbs"

  entitlements = extract_entitlements(binary) if RUBY_PLATFORM.include?('darwin')

  data = File.binread(binary).dup
  data.force_encoding('BINARY')

  arrays = find_js_arrays(data)
  abort "Could not find verb arrays. Is this Claude Code >= 2.x?" if arrays.empty?

  arrays.each_with_index do |(arr_start, arr_end), i|
    original = data[arr_start..arr_end]
    replacement = build_replacement(original.bytesize, verbs)
    data[arr_start, original.bytesize] = replacement.encode('UTF-8').b
    puts "  Patched array #{i} (#{original.bytesize} bytes)"
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

  puts "Done!"
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
  arrays = find_js_arrays(data)
  abort "No verb arrays found." if arrays.empty?

  read_js_array(data, *arrays.first).each { |v| puts v }
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
