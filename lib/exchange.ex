defmodule Exchange do
  @moduledoc """
  Documentation for `Exchange`.

  ## Usage

  Exchange.start_link/1 receives an optional keyword argument. Addition to the GenServer
  options, it can be specified with the following options:

  * order_book(optional): A data type that implements the OrderBook protocol. If
  order_book is not specified, the default implementation of ListOrderBook
  will be used.

  * store(optional): A data type that implements the Store protocol. If the store is not specified,
  then the Exchange will not persist the order events.

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
  Enum

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
    order_book = OrderBook.impl_for(order_book) || @default_order_book

    {store, opts} = Keyword.pop(opts, :store)

    GenServer.start_link(__MODULE__, [order_book: order_book, store: store], opts)
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
  @spec init(keyword()) :: {:ok, %{store: nil | Store.t(), order_book: OrderBook.t()}, {:continue, :init}}
  def init(opts) do
    state = Enum.into(opts, %{})
    {:ok, state, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, state = %{store: store}) do
    store1 =
      with mod when not is_nil(mod) <- Store.impl_for(store),
           {:ok, opened_store} <- Store.open(store) do
        opened_store
      else
        nil -> nil
        # [TODO]Log warning message open store error
        {:error, _} -> nil
      end

    {:noreply, %{state | store: store1}}
  end

  @impl true
  def handle_call(event = {:instr, :new, index, order}, _from, state) do
    state.store && Store.write(state.store, event)

    {:ok, updated_ob} = OrderBook.insert(state.order_book, index, order)

    {:reply, :ok, %{state | order_book: updated_ob}}
  end

  def handle_call(event = {:instr, :update, index, order}, _from, state) do
    state.store && Store.write(state.store, event)

    case OrderBook.update(state.order_book, index, order) do
      {:ok, updated_ob} ->
        {:reply, :ok, %{state | order_book: updated_ob}}

      {:error, :price_level_not_exist} = error ->
        {:reply, error, state}
    end
  end

  def handle_call(event = {:instr, :delete, index, order}, _from, state) do
    state.store && Store.write(state.store, event)

    case OrderBook.delete(state.order_book, index, order) do
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

  @impl true
  def terminate(_reason, state) do
    state.store && Store.close(state.store)
  end
end
