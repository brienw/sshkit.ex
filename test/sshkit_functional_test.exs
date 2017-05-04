defmodule SSHKitFunctionalTest do
  @moduledoc false

  import SSHKit.FunctionalCaseHelpers

  use SSHKit.FunctionalCase, async: true

  @defaults [silently_accept_hosts: true]

  def options(overrides) do
    Keyword.merge(@defaults, overrides)
  end

  def build_context(host) do
    SSHKit.context({
      host.ip,
      options(port: host.port,
              user: host.user,
              password: host.password,
              timeout: 5000
             )
    })
  end

  defp stdio(output, type) do
    output
    |> Keyword.get_values(type)
    |> Enum.join()
  end

  def stdout(output), do: stdio(output, :stdout)
  def stderr(output), do: stdio(output, :stderr)

  @tag boot: 1
  test "connects", %{hosts: [host]} do
    [{:ok, output, 0}] = SSHKit.run(build_context(host), "id -un")
    name = String.trim(stdout(output))
    assert name == host.user
  end

  @tag boot: 1
  test "runs commands", %{hosts: [host]} do
    context = build_context(host)

    [{:ok, output, status}] = SSHKit.run(context, "pwd")
    assert status == 0
    assert stdout(output) == "/home/me\n"

    [{:ok, output, status}] = SSHKit.run(context, "ls non-existing")
    assert status == 1
    assert stderr(output) =~ "ls: non-existing: No such file or directory"

    [{:ok, output, status}] = SSHKit.run(context, "does-not-exist")
    assert status == 127
    assert stderr(output) =~ "'does-not-exist': No such file or directory"
  end

  @tag :skip # not yet implemented
  @tag boot: 1
  test "env", %{hosts: [host]} do
    [{:ok, output, status}] =
      host
      |> build_context()
      |> SSHKit.env(%{"PATH" => "$HOME/.rbenv/shims:$PATH"})
      |> SSHKit.env(%{"NODE_ENV" => "production"})
      |> SSHKit.run("env")

    output = stdout(output)

    assert status == 0
    assert output =~ "NODE_ENV=production"
    assert output =~ ~r/PATH=.*\/\.rbenv\/shims:/
  end

  @tag boot: 1
  test "umask", %{hosts: [host]} do
    context =
      host
      |> build_context()
      |> SSHKit.umask("077")

    [{:ok, _, 0}] = SSHKit.run(context, "mkdir my_dir")
    [{:ok, _, 0}] = SSHKit.run(context, "touch my_file")

    [{:ok, output, status}] = SSHKit.run(context, "ls -la")

    output = stdout(output)

    assert status == 0
    assert output =~ ~r/drwx--S---\s+2\s+me\s+me\s+4096.+my_dir/
    assert output =~ ~r/-rw-------\s+1\s+me\s+me\s+0.+my_file/
  end

  @tag boot: 1
  test "path", %{hosts: [host]} do
    context =
      host
      |> build_context
      |> SSHKit.path("/var/log")

    [{:ok, output, status}] = SSHKit.run(context, "pwd")
    output = stdout(output)

    assert status == 0
    assert output == "/var/log\n"
  end

  @tag boot: 1
  test "user", %{hosts: [host]} do
    adduser(host, "despicable_me")

    context =
      host
      |> build_context()
      |> SSHKit.user("despicable_me")

    [{:ok, output, status}] = SSHKit.run(context, "id -un")
    # IO.inspect(stderr(output))
    output = stdout(output)

    assert output == "despicable_me\n"
    assert status == 0
  end

  @tag boot: 1
  test "group", %{hosts: [host]} do
    adduser(host, "gru")
    addgroup(host, "villains")
    addgroup(host, "minion_owners")
    add_user_to_group(host, "gru", "villains")
    add_user_to_group(host, "gru", "minion_owners")

    context = build_context(host)

    [{:ok, output, status}] =
      context
      |> SSHKit.user("gru")
      |> SSHKit.group("villains")
      |> SSHKit.run("id -gn")

    IO.inspect(stderr(output))
    output = stdout(output)

    assert output == "villains\n"
    assert status == 0

    [{:ok, output, status}] =
      context
      |> SSHKit.user("gru")
      |> SSHKit.group("minion_owners")
      |> SSHKit.run("id -gn")

    output = stdout(output)

    assert output == "minion_owners\n"
    assert status == 0
  end
end
