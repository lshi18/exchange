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

  @doc """
  Start link
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @spec send_instruction(pid(), map()) :: :ok
  def send_instruction(pid, event) do
    GenServer.call(pid, {:instr, event})
  end

  def order_book(pid, book_depth) do
    GenServer.call(pid, {:order_book, book_depth})
  end

  @impl true
  def init(_opts) do
    {:ok, %{order_book: SimpleListOrderBook.new()}}
  end

  @impl true
  def handle_call({:instr, event = %{instruction: :new}}, _from, state = %{order_book: ob}) do
    updated_ob =
      SimpleListOrderBook.insert(
        ob,
        Map.take(event, [:side, :quantity, :price_level_index, :price])
      )

    {:reply, :ok, %{state | order_book: updated_ob}}
  end

  def handle_call({:instr, event = %{instruction: :update}}, _from, state = %{order_book: ob}) do
    case SimpleListOrderBook.update(
           ob,
           Map.take(event, [:side, :quantity, :price_level_index, :price])
         ) do
      {:ok, updated_ob} ->
        {:reply, :ok, %{state | order_book: updated_ob}}

      {:error, :price_level_not_existed} = error ->
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

  def insert({bids, asks}, bid = %{price_level_index: pl_index, side: :bid}) do
    {insert_at(bids, pl_index, bid.price, bid.quantity), asks}
  end

  def insert({bids, asks}, ask = %{price_level_index: pl_index, side: :ask}) do
    {bids, insert_at(asks, pl_index, ask.price, ask.quantity)}
  end

  def update({bids, asks}, bid = %{price_level_index: pl_index, side: :bid}) do
    case update_at(bids, pl_index, bid.price, bid.quantity) do
      {:error, _} = error ->
        error

      updated_bids ->
        {:ok, {updated_bids, asks}}
    end
  end

  def update({bids, asks}, ask = %{price_level_index: pl_index, side: :ask}) do
    case update_at(asks, pl_index, ask.price, ask.quantity) do
      {:error, _} = error ->
        error

      updated_asks ->
        {:ok, {bids, updated_asks}}
    end
  end

  defp update_at(list, pl_index, price, quantity) do
    try do
      update_in(list, [Access.at!(pl_index - 1)], fn pl -> %{pl | q: quantity, p: price} end)
    catch
      _, _ ->
        {:error, :price_level_not_existed}
    end
  end

  defp insert_at([], 1, price, quantity) do
    [%{q: quantity, p: price}]
  end

  defp insert_at([head | tail], 1, price, quantity) do
    [%{q: quantity, p: price}, head | tail]
  end

  defp insert_at([head | tail], pl_index, price, quantity) do
    [head | insert_at(tail, pl_index - 1, price, quantity)]
  end

  def match_order({bids, asks}, order_depth) do
    [bids, asks]
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
end
