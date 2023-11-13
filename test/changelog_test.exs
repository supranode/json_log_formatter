defmodule CHANGELOGTest do
  use ExUnit.Case, async: true

  test "CHANGELOG entry" do
    app_version = Version.parse!("#{Application.spec(:json_log_formatter, :vsn)}")

    assert File.read!("CHANGELOG.md") =~ "## v#{app_version} ",
           "Missing entry for version #{app_version} in CHANGELOG.md"
  end
end
