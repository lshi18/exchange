defprotocol Store do
  def open(store)
  def write(store, event)
  def read(store)
  def close(store)
end

defmodule FileStore do
  @moduledoc """
  A file-backed representation of the store, which implements the Store protocol.

  It provides the most basic functionality of writing out to a file in a CSV format.
  """

  @enforce_keys [:filename]
  defstruct [:filename, :fd]
end

defimpl Store, for: FileStore do
  def open(store) do
    case File.open(store.filename, [:append, :write]) do
      {:error, _} = error -> error
      {:ok, fd} -> {:ok, %{store | fd: fd}}
    end
  end

  def write(store, event) do
    IO.write(store.fd, format(event))
  end

  def read(_store) do
    # It is unused, thus not implemented
    []
  end

  def close(store) do
    File.close(store.fd)
  end

  def format({:instr, type, index, order}) do
    "#{type};#{index};#{order.side};#{order[:price]};#{order[:quantity]}\n"
  end
end
