#!/usr/bin/env ruby
# frozen_string_literal: true
#
# git-merge-structure-sql - git merge driver for db/structure.sql in a Rails project
#
# How to use:
#     $ git-merge-structure-sql --install
#
# Copyright (c) 2018-2021 Akinori MUSHA
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

class StructureSqlMergeDriver
  VERSION = '1.1.2'
  VARIANTS = []

  module Default # This covers PostgreSQL, SQLite and newer MySQL formats.
    RE_VERSION = /^\('(\d+)'\)[,;]\n/
    RE_VERSIONS = /^INSERT INTO (?<q>["`])schema_migrations\k<q> \(version\) VALUES\n\K#{RE_VERSION}+/

    class << self
      def match?(content)
        RE_VERSIONS === content
      end

      def merge!(*contents)
        merge_versions!(*contents)
      end

      private

      def merge_versions!(*contents)
        replacement = format_versions(
          contents.inject([]) { |versions, content|
            versions | content[RE_VERSIONS].scan(RE_VERSION).flatten
          }.sort
        )

        contents.each { |content|
          content.sub!(RE_VERSIONS, replacement)
        }
      end

      def format_versions(versions)
        versions.map { |version| "('%s')" % version }.join(",\n") << ";\n"
      end
    end

    VARIANTS.unshift self
  end

  module Postgresql # This covers PostgreSQL with leading commas
    RE_VERSION = /^[, ]\('(\d+)'\)\n/
    RE_VERSIONS = /^INSERT INTO (?<q>["`])schema_migrations\k<q> \(version\) VALUES\n\K#{RE_VERSION}+;/

    class << self
      def match?(content)
        RE_VERSIONS === content
      end

      def merge!(*contents)
        merge_versions!(*contents)
      end

      private

      def merge_versions!(*contents)
        replacement = format_versions(
          contents.inject([]) { |versions, content|
            versions | content[RE_VERSIONS].scan(RE_VERSION).flatten
          }.sort
        )

        contents.each { |content|
          content.sub!(RE_VERSIONS, replacement)
        }
      end

      def format_versions(versions)
        " " + versions.map { |version| "('%s')" % version }.join("\n,") << "\n;"
      end
    end

    VARIANTS.unshift self
  end

  module MySQL
    class << self
      RE_DUMP_TIMESTAMP = /^-- Dump completed on \K.+$/
      RE_AUTO_INCREMENT_VALUE = /^\)(?= ).*\K AUTO_INCREMENT=\d+(?=.*;$)/
      RE_VERSION = /^INSERT INTO schema_migrations \(version\) VALUES \('(\d+)'\);\s+/
      RE_VERSIONS = /#{RE_VERSION}+/

      def match?(content)
        /^-- MySQL dump / === content
      end

      def merge!(*contents)
        merge_dump_timestamps!(*contents)
        scrub_auto_increment_values!(*contents)
        merge_versions!(*contents)
      end

      private

      def merge_dump_timestamps!(*contents)
        replacement = contents.inject('') { |timestamp, content|
          [timestamp, *content.scan(RE_DUMP_TIMESTAMP)].max rescue ''
        }

        unless replacement.empty?
          contents.each { |content|
            content.gsub!(RE_DUMP_TIMESTAMP, replacement)
          }
        end
      end

      def scrub_auto_increment_values!(*contents)
        contents.each { |content|
          content.gsub!(RE_AUTO_INCREMENT_VALUE, '')
        }
      end

      def merge_versions!(*contents)
        replacement = format_versions(
          contents.inject([]) { |versions, content|
            versions | content.scan(RE_VERSION).flatten
          }.sort
        )

        contents.each { |content|
          content.sub!(RE_VERSIONS, replacement)
        }
      end

      def format_versions(versions)
        versions.map { |version| "INSERT INTO schema_migrations (version) VALUES ('%s');\n\n" % version }.join
      end
    end

    VARIANTS.unshift self
  end

  def system!(*args)
    system(*args) or exit $?.exitstatus
  end

  def main(*argv)
    require 'optparse'
    require 'shellwords'

    myname = File.basename($0)
    driver_name = 'merge-structure-sql'

    banner = <<~EOF
      #{myname} - git merge driver for db/structure.sql in a Rails project #{VERSION}

      usage: #{myname} <current-file> <base-file> <other-file>
             #{myname} --install

    EOF

    install = false

    opts = OptionParser.new(banner) { |opts|
      opts.version = VERSION
      opts.summary_indent = ''
      opts.summary_width = 24

      opts.on('--install[={global|local}]',
        "Enable this merge driver in Git (default: global)") { |val|
        case install = val&.to_sym || :global
        when :global, :local
          # ok
        else
          raise OptionParser::InvalidArgument, "--install=#{val}: unknown argument"
        end
      }
    }

    files = opts.order(argv)

    if install
      global = install == :global

      git_config = ["git", "config", *("--global" if global)]

      config_file = `GIT_EDITOR=echo #{git_config.shelljoin} -e 2>/dev/null`.chomp

      puts "#{config_file}: Adding the \"#{driver_name}\" driver definition"

      system!(
        *git_config,
        "merge.#{driver_name}.name",
        "Rails structure.sql merge driver"
      )
      system!(
        *git_config,
        "merge.#{driver_name}.driver",
        "#{myname.shellescape} %A %O %B"
      )

      attributes_file =
        if global
          filename = `git config --global core.attributesfile`.chomp

          if $?.success?
            File.expand_path(filename)
          else
            [
              [File.join(ENV['XDG_CONFIG_HOME'] || '~/.config', 'git'), 'attributes'],
              ['~', '.gitattributes']
            ].find { |dir, file|
              if File.directory?(File.expand_path(dir))
                system!(*%W[
                  git config --global core.attributesfile #{File.join(dir, file)}
                ])
                break File.expand_path(file, dir)
              end
            } or raise "don't you have home?"
          end
        else
          git_dir = `git rev-parse --git-dir`.chomp

          if $?.success?
            File.expand_path(File.join('info', 'attributes'), git_dir)
          else
            raise "not in a git directory"
          end
        end

      File.open(attributes_file, 'a+') { |f|
        pattern = /^\s*structure.sql\s+(?:\S+\s+)*merge=#{Regexp.quote(driver_name)}(?:\s|$)/
        break if f.any? { |line| pattern === line }

        puts "#{attributes_file}: Registering the \"#{driver_name}\" driver for structure.sql"
        f.puts if f.pos > 0
        f.puts "structure.sql merge=#{driver_name}"
      }

      exit
    end

    unless files.size == 3
      STDERR.print opts.help
      exit 64
    end

    contents = files.map { |file| File.read(file) }

    sample = contents[0]
    if variant = VARIANTS.find { |v| v.match?(sample) }
      variant.merge!(*contents)

      files.zip(contents) do |file, content|
        File.write(file, content)
      end
    else
      STDERR.puts "#{myname}: Unsupported format; falling back to git-merge-file(1)"
    end

    exec(*%W[git merge-file -q], *files)
  rescue => e
    STDERR.puts "#{myname}: #{e.message}"
    exit 1
  end
end

if $0 == __FILE__
  StructureSqlMergeDriver.new.main(*ARGV)
end
