# Copyright (C) 2012  Kouhei Sutou <kou@clear-code.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "stringio"
require "rack/utils"
require "groonga/tester"

class TestExecutor < Test::Unit::TestCase
  def setup
    input = StringIO.new
    output = StringIO.new
    @executor = Groonga::Tester::Executor.new(input, output)
    @context = @executor.context
    @script = Tempfile.new("test-executor")
  end

  private
  def execute(command)
    @script.print(command)
    @script.close
    @executor.execute(Pathname(@script.path))
  end

  class TestComment < self
    def test_disable_logging
      assert_predicate(@context, :logging?)
      execute("# disable-logging")
      assert_not_predicate(@context, :logging?)
    end

    def test_enable_logging
      @context.logging = false
      assert_not_predicate(@context, :logging?)
      execute("# enable-logging")
      assert_predicate(@context, :logging?)
    end

    def test_suggest_create_dataset
      mock(@executor).execute_suggest_create_dataset("shop")
      execute("# suggest-create-dataset shop")
    end
  end

  class TestTranslate < self
    def setup
      @translater = Groonga::Tester::Translater.new
    end

    def test_command
      command = "table_create Site TABLE_HASH_KEY ShortText"
      arguments = {
        "name" => "Site",
        "flags" => "TABLE_HASH_KEY",
        "key_type" => "ShortText",
      }
      actual_command = translate(command)
      expected_command = build_url("table_create", arguments)

      assert_equal(expected_command, actual_command)
    end

    def test_command_with_argument_name
      command = "select --table Sites"
      actual_command = translate(command)
      expected_command = build_url("select", "table" => "Sites")

      assert_equal(expected_command, actual_command)
    end

    def test_command_without_arguments
      command = "dump"
      actual_command = translate(command)
      expected_command = build_url(command, {})

      assert_equal(expected_command, actual_command)
    end

    def test_load_command
      load_command = "load --table Sites"
      load_values = <<EOF
[
["_key","uri"],
["groonga","http://groonga.org/"],
["razil","http://razil.jp/"]
]
EOF
      commands = "#{load_command}\n#{load_values}"
      actual_commands = commands.lines.collect do |line|
        translate(line)
      end

      expected_command = build_url("load", "table" => "Sites")
      expected_command << load_values_query(load_values)

      assert_equal(expected_command, actual_commands.join("\n"))
    end

    def test_load_command_with_json_value
      load_command = "load --table Sites"
      load_values = <<EOF
[
{"_key": "ruby", "uri": "http://ruby-lang.org/"}
]
EOF
      commands = "#{load_command}\n#{load_values}"
      actual_commands = commands.lines.collect do |line|
        translate(line)
      end

      expected_command = build_url("load", "table" => "Sites")
      expected_command << load_values_query(load_values)

      assert_equal(expected_command, actual_commands.join("\n"))
    end

    def test_command_with_single_quote
      command = "select Sites --output_columns '_key, uri'"
      arguments = {
        "table" => "Sites",
        "output_columns" => "_key,uri",
      }
      actual_command = translate(command)
      expected_command = build_url("select", arguments)

      assert_equal(expected_command, actual_command)
    end

    def test_comment
      comment = "#this is comment."
      expected_command = comment
      actual_command = translate(comment)

      assert_equal(expected_command, actual_command)
    end

    private
    def translate(command)
      @translater.translate_command(command)
    end

    def build_url(command, arguments)
      url = "/d/#{command}"
      query = Rack::Utils.build_query(arguments)
      url << "?#{query}" unless query.empty?
      url
    end

    def load_values_query(values)
      escaped_values = values.lines.collect do |line|
        "#{Rack::Utils.escape(line.chomp)}"
      end
      "&values=\n#{escaped_values.join("\n")}"
    end
  end
end
