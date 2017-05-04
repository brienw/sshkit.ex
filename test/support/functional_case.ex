defmodule SSHKit.FunctionalCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  import SSHKit.FunctionalCaseHelpers

  @image "sshkit-test-sshd"
  @cmd "/usr/sbin/sshd"
  @args ["-D", "-e"]

  @user "me"
  @pass "pass"

  using do
    quote do
      @moduletag :functional
    end
  end

  setup tags do
    count = Map.get(tags, :boot, 1)

    conf = %{image: @image, cmd: @cmd, args: @args}
    hosts = Enum.map(1..count, fn _ -> init(boot(conf)) end)

    on_exit fn -> kill(hosts) end

    {:ok, hosts: hosts}
  end

  def boot(config = %{image: image, cmd: cmd, args: args}) do
    id = Docker.run!(["--rm", "--publish-all", "--detach"], image, cmd, args)

    ip = Docker.host

    port =
      "port"
      |> Docker.cmd!([id, "22/tcp"])
      |> String.split(":")
      |> List.last
      |> String.to_integer

    Map.merge(config, %{id: id, ip: ip, port: port})
  end

  def init(host) do
    adduser(host, @user)
    addgroup(host, "sudo")
    add_user_to_group(host, @user, "sudo")
    chpasswd(host, @user, @pass)
    keygen(host, @user)

    # TODO: Add case with passwd required (make default?)
    Docker.exec!([], host.id, "sh", ["-c", "echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"])

    Map.merge(host, %{user: @user, password: @pass})
  end

  def kill(hosts) do
    running = Enum.map(hosts, &(Map.get(&1, :id)))
    killed = Docker.kill!(running)
    diff = running -- killed
    if Enum.empty?(diff), do: :ok, else: {:error, diff}
  end
end
