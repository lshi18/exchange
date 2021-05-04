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
    iex> Exchange.send_instruction(exchange_pid, %{
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

  use GenServer

  @sides [:bid, :ask]
  @instr_types [:new, :update, :delete]

  @doc """
  Start link
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @spec send_instruction(pid(), map()) :: :ok
  def send_instruction(
        pid,
        event = %{instruction: instr_type, price_level_index: index, side: side}
      )
      when index > 0 and side in @sides and instr_type in @instr_types do
    order = Map.take(event, [:side, :price, :quantity])
    GenServer.call(pid, {:instr, instr_type, index, order})
  end

  def send_instruction(_, event) do
    raise("Event format error: #{event}")
  end

  def order_book(pid, book_depth) do
    GenServer.call(pid, {:order_book, book_depth})
  end

  @impl true
  def init(_opts) do
    {:ok, %{order_book: SimpleListOrderBook.new()}}
  end

  @impl true
  def handle_call({:instr, :new, index, order}, _from, state = %{order_book: ob}) do
    updated_ob = SimpleListOrderBook.insert(ob, index, order)

    {:reply, :ok, %{state | order_book: updated_ob}}
  end

  def handle_call({:instr, :update, index, order}, _from, state = %{order_book: ob}) do
    case SimpleListOrderBook.update(ob, index, order) do
      {:ok, updated_ob} ->
        {:reply, :ok, %{state | order_book: updated_ob}}

      {:error, :price_level_not_exist} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:instr, :delete, index, order}, _from, state = %{order_book: ob}) do
    case SimpleListOrderBook.delete(ob, index, order) do
      {:ok, updated_ob} ->
        {:reply, :ok, %{state | order_book: updated_ob}}

      {:error, :price_level_not_exist} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:order_book, book_depth}, _from, state = %{order_book: ob}) do
    order_book = SimpleListOrderBook.match_order(ob, book_depth)
    {:reply, order_book, state}
  end
end

defmodule SimpleListOrderBook do
  def new() do
    {[], []}
  end

  def insert({bids, asks}, pl_index, order) do
    case order.side do
      :bid ->
        updated_bids = insert_at(bids, pl_index, order.price, order.quantity)
        {updated_bids, asks}

      :ask ->
        updated_asks = insert_at(asks, pl_index, order.price, order.quantity)
        {bids, updated_asks}
    end
  end

  def update({bids, asks}, pl_index, order = %{side: :bid}) do
    case update_at(bids, pl_index, order.price, order.quantity) do
      {:error, _} = error ->
        error

      updated_bids ->
        {:ok, {updated_bids, asks}}
    end
  end

  def update({bids, asks}, pl_index, order = %{side: :ask}) do
    case update_at(asks, pl_index, order.price, order.quantity) do
      {:error, _} = error ->
        error

      updated_asks ->
        {:ok, {bids, updated_asks}}
    end
  end

  def delete({bids, asks}, pl_index, %{side: :bid}) do
    try do
      updated_bids = delete_at(bids, pl_index)
      {:ok, {updated_bids, asks}}
    rescue
      ArgumentError ->
        {:error, :price_level_not_exist}
    end
  end

  def delete({bids, asks}, pl_index, %{side: :ask}) do
    try do
      updated_asks = delete_at(asks, pl_index)
      {:ok, {bids, updated_asks}}
    rescue
      ArgumentError ->
        {:error, :price_level_not_exist}
    end
  end

  def match_order({bids, asks}, order_depth) do
    make_stream_with_defaults = fn orders ->
      Stream.concat(orders, Stream.repeatedly(fn -> %{p: 0, q: 0} end))
    end

    [bids, asks]
    |> Stream.map(make_stream_with_defaults)
    |> Stream.zip()
    |> Enum.take(order_depth)
    |> Enum.map(fn {bid, ask} ->
      %{
        ask_price: ask.p,
        ask_quantity: ask.q,
        bid_price: bid.p,
        bid_quantity: bid.q
      }
    end)
  end

  # Helper functions

  defp update_at(list, pl_index, price, quantity) do
    try do
      update_in(list, [Access.at!(pl_index - 1)], fn pl -> %{pl | q: quantity, p: price} end)
    catch
      _, _ ->
        {:error, :price_level_not_exist}
    end
  end

  defp insert_at([], 1, price, quantity), do: [%{q: quantity, p: price}]

  defp insert_at([], pl_index, price, quantity),
    do: [%{q: 0, p: 0} | insert_at([], pl_index - 1, price, quantity)]

  defp insert_at([head | tail], 1, price, quantity), do: [%{q: quantity, p: price}, head | tail]

  defp insert_at([head | tail], pl_index, price, quantity),
    do: [head | insert_at(tail, pl_index - 1, price, quantity)]

  defp delete_at([], _pl_index), do: raise(ArgumentError, "price_index_not_exist")
  defp delete_at([_head | tail], 1), do: tail
  defp delete_at([head | tail], pl_index), do: [head | delete_at(tail, pl_index - 1)]
end
