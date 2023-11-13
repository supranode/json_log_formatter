defmodule READMETest do
  use ExUnit.Case, async: true

  test "README installation instructions version" do
    app_version = Version.parse!("#{Application.spec(:json_log_formatter, :vsn)}")
    expected_readme_version = "#{app_version.major}.#{app_version.minor}"

    readme = File.read!("README.md")
    [_, readme_version] = Regex.run(~r/{:json_log_formatter, "~> (\d+\.\d+)"/, readme)

    assert readme_version == expected_readme_version,
           """
           Install version in README.md does not match to current app version.
           Current app version: #{app_version}
           README install version: ~> #{readme_version}
           Expected README install version: ~> #{expected_readme_version}
           """
  end
end
