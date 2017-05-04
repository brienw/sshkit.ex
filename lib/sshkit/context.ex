defmodule SSHKit.Context do
  @moduledoc false

  import SSHKit.Utils

  defstruct [hosts: [], env: nil, path: nil, umask: nil, user: nil, group: nil]

  def build(context, command) do
    command
    |> cmd()
    |> sudo(context.user, context.group)
    |> env(context.env)
    |> umask(context.umask)
    |> cd(context.path)
  end

  defp cmd(command), do: "/usr/bin/env #{command}"

  defp sudo(command, nil, nil), do: command
  defp sudo(command, username, nil), do: "sudo -n -u #{username} -- sh -c #{shellquote(command)}"
  defp sudo(command, nil, groupname), do: "sudo -n -g #{groupname} -- sh -c #{shellquote(command)}"
  defp sudo(command, username, groupname), do: "sudo -n -u #{username} -g #{groupname} -- sh -c #{shellquote(command)}"

  defp env(command, nil), do: command
  defp env(command, %{}), do: command
  defp env(command, env) do
    exports = Enum.map_join(env, " ", fn {name, value} -> "#{name}=#{value}" end)
    "(export #{exports} && #{shellquote(command)})"
  end

  defp umask(command, nil), do: command
  defp umask(command, mask), do: "umask #{mask} && #{command}"

  defp cd(command, nil), do: command
  defp cd(command, path), do: "cd #{path} && #{command}"
end
