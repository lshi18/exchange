defprotocol OrderBook do
  @type order_book ::
          list(%{
            bid_price: float(),
            bid_quantity: integer(),
            ask_price: float(),
            ask_quantity: integer()
          })

  @spec insert(t(), pos_integer(), map()) :: {:ok, t()}
  def insert(order_book, price_level_index, order)

  @spec update(t(), pos_integer(), map()) :: {:ok, t()} | {:error, :price_level_not_exist}
  def update(order_book, price_level_index, order)

  @spec delete(t(), pos_integer(), map()) :: {:ok, t()} | {:error, :price_level_not_exist}
  def delete(order_book, price_level_index, order)

  @spec match_order(t(), pos_integer()) :: list(map())
  def match_order(order_book, book_depth)
end

defmodule ListOrderBook do
  @moduledoc """
  ListOrderBook defines a simple representation of the order book based
  on elixir's List.

  An implementation of the OrderBook protocol is provided for the ListOrderBook.

  ## Performance

  Due to the fact that elixir's List is implemented as linked lists, the time complexity
  of the insertion, update and deletion operations is O(n) (where n is the price level index
  provided in the event). And the time complexity of the order match query is O(k) where k
  is the book depth for the query.

  In case of large n and k, the performance of this implementation could degenerate. In such use
  cases, it is recommended that performance test be carried out and that alternative book order
  be implemented if necessary.
  """

  defstruct asks: [], bids: []
end

defimpl OrderBook, for: ListOrderBook do
  @default_order %{p: 0, q: 0}

  def insert(ob, pl_index, order) do
    case order.side do
      :bid ->
        updated_bids = insert_at(ob.bids, pl_index, order.price, order.quantity)
        {:ok, %{ob | bids: updated_bids}}

      :ask ->
        updated_asks = insert_at(ob.asks, pl_index, order.price, order.quantity)
        {:ok, %{ob | asks: updated_asks}}
    end
  end

  def update(ob, pl_index, order) do
    case order.side do
      :bid ->
        updated_bids = update_at(ob.bids, pl_index, order.price, order.quantity)
        {:bid, updated_bids}

      :ask ->
        updated_asks = update_at(ob.asks, pl_index, order.price, order.quantity)
        {:ask, updated_asks}
    end
    |> case do
      {_side, :error} ->
        {:error, :price_level_not_exist}

      {:bid, result} ->
        {:ok, %{ob | bids: result}}

      {:ask, result} ->
        {:ok, %{ob | asks: result}}
    end
  end

  def delete(ob, pl_index, order) do
    case order.side do
      :bid ->
        updated_bids = delete_at(ob.bids, pl_index)
        {:bid, updated_bids}

      :ask ->
        updated_asks = delete_at(ob.asks, pl_index)
        {:ask, updated_asks}
    end
    |> case do
      {_side, :error} ->
        {:error, :price_level_not_exist}

      {:bid, result} ->
        {:ok, %{ob | bids: result}}

      {:ask, result} ->
        {:ok, %{ob | asks: result}}
    end
  end

  def match_order(ob, book_depth) do
    make_stream_with_defaults = fn orders ->
      Stream.concat(orders, Stream.repeatedly(fn -> @default_order end))
    end

    [ob.bids, ob.asks]
    |> Stream.map(make_stream_with_defaults)
    |> Stream.zip()
    |> Enum.take(book_depth)
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

  defp update_at(list, index, price, quantity) do
    try do
      update_in(list, [Access.at!(index - 1)], fn pl -> %{pl | q: quantity, p: price} end)
    catch
      _, _ ->
        :error
    end
  end

  defp insert_at([], 1, price, quantity), do: [%{q: quantity, p: price}]

  # Insert beyond the end of current price levels, insert default ones.
  defp insert_at([], pl_index, price, quantity),
    do: [@default_order | insert_at([], pl_index - 1, price, quantity)]

  defp insert_at([head | tail], 1, price, quantity), do: [%{q: quantity, p: price}, head | tail]

  defp insert_at([head | tail], pl_index, price, quantity),
    do: [head | insert_at(tail, pl_index - 1, price, quantity)]

  defp delete_at(list, index) do
    try do
      {_, l} = pop_in(list, [Access.at!(index - 1)])
      l
    catch
      _, _ ->
        :error
    end
  end
end
