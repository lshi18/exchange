defmodule Exchange do
  @moduledoc """
  Documentation for `Exchange`.

  ## Examples

    iex> {:ok, exchange_pid} = Exchange.start_link()
    iex> Exchange.send_instruction(exchange_pid, %{
    ...>    instruction: :new,
    ...>    side: :bid,
    ...>    price_level_index: 1,
    ...>    price: 50.0,
    ...>    quantity: 30
    ...>    })
    :ok
    iex> Exchange.send_instruction(exchange_pid, %{
    ...>    instruction: :new,
    ...>    side: :bid,
    ...>    price_level_index: 2,
    ...>    price: 40.0,
    ...>    quantity: 40
    ...>    })
    :ok
    iex> Exchange.send_instruction(exchange_pid, %{
    ...>    instruction: :new,
    ...>    side: :ask,
    ...>    price_level_index: 1,
    ...>    price: 60.0,
    ...>    quantity: 10
    ...>    })
    :ok
    iex> Exchange.send_instruction(exchange_pid, %{
    ...>    instruction: :new,
    ...>    side: :ask,
    ...>    price_level_index: 2,
    ...>    price: 70.0,
    ...>    quantity: 10
    ...>    })
    :ok
    iex(6)> Exchange.send_instruction(exchange_pid, %{
    ...>    instruction: :update,
    ...>    side: :ask,
    ...>    price_level_index: 2,
    ...>    price: 70.0,
    ...>    quantity: 20
    ...>    })
    :ok
    iex> Exchange.send_instruction(exchange_pid, %{
    ...>    instruction: :update,
    ...>    side: :bid,
    ...>    price_level_index: 1,
    ...>    price: 50.0,
    ...>    quantity: 40
    ...>    })
    :ok
    iex> Exchange.order_book(exchange_pid, 2)
    [
      %{ask_price: 60.0, ask_quantity: 10, bid_price: 50.0, bid_quantity: 40},
      %{ask_price: 70.0, ask_quantity: 20, bid_price: 40.0, bid_quantity: 40}
    ]
  """

  @doc """
  Start link
  """
  def start_link() do
    {:ok, nil}
  end

  @spec send_instruction(pid(), map()) :: :ok
  def send_instruction(_pid, _event) do
    :ok
  end

  def order_book(_pid, _book_depth) do
    []
  end
end
