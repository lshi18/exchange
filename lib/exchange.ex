defmodule Exchange do
  @moduledoc """
  Documentation for `Exchange`.

  ## Usage

  Exchange.start_link/1 receives an optional keyword argument. In particular,
  an :order_book key and an OrderBook value can be specified. The OrderBook value
  should be a datatype (struct) that implements the OrderBook protocol. If the
  :order_book is not specified, then the default implementation of ListOrderBook
  will be used.

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

  @type event :: %{
          instruction: :new | :update | :delete,
          side: :bid | :ask,
          price_level_index: integer(),
          price: float(),
          quantity: integer()
        }

  @sides [:bid, :ask]
  @instr_types [:new, :update, :delete]
  @default_order_book %ListOrderBook{}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {order_book, opts} = Keyword.pop(opts, :order_book)
    order_book = order_book || @default_order_book
    GenServer.start_link(__MODULE__, [order_book: order_book], opts)
  end

  @spec send_instruction(pid(), event()) :: :ok | {:error, term()}
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

  @spec order_book(pid(), pos_integer()) :: list(OrderBook.order_book())
  def order_book(pid, book_depth) do
    GenServer.call(pid, {:order_book, book_depth})
  end

  @impl true
  @spec init(order_book: OrderBook.t()) :: {:ok, %{order_book: OrderBook.t()}}
  def init(order_book: order_book) do
    {:ok, %{order_book: order_book}}
  end

  @impl true
  def handle_call({:instr, :new, index, order}, _from, state = %{order_book: ob}) do
    {:ok, updated_ob} = OrderBook.insert(ob, index, order)

    {:reply, :ok, %{state | order_book: updated_ob}}
  end

  def handle_call({:instr, :update, index, order}, _from, state = %{order_book: ob}) do
    case OrderBook.update(ob, index, order) do
      {:ok, updated_ob} ->
        {:reply, :ok, %{state | order_book: updated_ob}}

      {:error, :price_level_not_exist} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:instr, :delete, index, order}, _from, state = %{order_book: ob}) do
    case OrderBook.delete(ob, index, order) do
      {:ok, updated_ob} ->
        {:reply, :ok, %{state | order_book: updated_ob}}

      {:error, :price_level_not_exist} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:order_book, book_depth}, _from, state = %{order_book: ob}) do
    order_book = OrderBook.match_order(ob, book_depth)
    {:reply, order_book, state}
  end
end
