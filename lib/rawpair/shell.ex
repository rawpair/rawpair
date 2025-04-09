defmodule Shell do
  def escape_value(value) do
    value
    |> String.replace("\\", "\\\\")  # Escape backslashes
    |> String.replace("\"", "\\\"")  # Escape double quotes
    |> (&("\"#{&1}\"")).()           # Wrap the value in double quotes
  end
end
