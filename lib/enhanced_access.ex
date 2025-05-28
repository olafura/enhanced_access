defmodule EnhancedAccess do
  @moduledoc """
  Documentation for `EnhancedAccess`.
  """

  @doc """
  Be able to access any key in a Map or a Keyword list through the Access protocol

  ## Examples

      iex> get_in(%{a: %{b: 1}, c: %{b: 2}}, [EnhancedAccess.all_keys(), :b])
      [1, 2]

      iex> get_in(%{a: %{b: 1}, c: %{b: 2}}, [EnhancedAccess.all_keys()])
      [%{b: 1}, %{b: 2}]

      iex> get_in([a: %{b: 1}, c: %{b: 2}], [EnhancedAccess.all_keys()])
      [%{b: 1}, %{b: 2}]

      iex> deeper_nesting = %{a: %{b: %{c: 1}}, d: %{b: %{c: 2}}, e: %{b: 1}}
      iex> get_in(deeper_nesting, [EnhancedAccess.all_keys(), :b, EnhancedAccess.optional_key(:c)])
      [1, 2, nil]

      iex> update_in(%{a: %{b: 1}, c: %{b: 2}}, [EnhancedAccess.all_keys(), :b], &(&1 + 1))
      %{a: %{b: 2}, c: %{b: 3}}

      iex> update_in([a: %{b: 1}, c: %{b: 2}], [EnhancedAccess.all_keys(), :b], &(&1 + 1))
      [a: %{b: 2}, c: %{b: 3}]

      iex> update_in([a: [b: 1], c: [b: 2]], [EnhancedAccess.all_keys(), :b], &(&1 + 1))
      [a: [b: 2], c: [b: 3]]

      iex> get_and_update_in(%{a: %{b: 1}, c: %{b: 2}}, [EnhancedAccess.all_keys(), :b], &{&1, &1 + 1})
      {[1, 2], %{a: %{b: 2}, c: %{b: 3}}}

      iex> pop_in(%{a: %{b: 1}, c: %{b: 2}}, [EnhancedAccess.all_keys(), :b])
      {[1, 2], %{a: %{}, c: %{}}}
  """
  @spec all_keys() :: Access.access_fun(data :: Access.container(), current_value :: term)
  def all_keys do
    &all_keys/3
  end

  defp all_keys(:get, data, next) when is_map(data) or is_list(data) do
    Enum.map(data, fn {_, value} -> next.(value) end)
  end

  defp all_keys(:get_and_update, data, next) when is_map(data) do
    do_all_keys(Map.to_list(data), next, _gets = [], _updates = [], %{})
  end

  defp all_keys(:get_and_update, data, next) when is_list(data) do
    do_all_keys(data, next, _gets = [], _updates = [], [])
  end

  defp do_all_keys([{key, value} | rest], next, gets, updates, into) do
    case next.(value) do
      {get, update} -> do_all_keys(rest, next, [get | gets], [{key, update} | updates], into)
      :pop -> do_all_keys(rest, next, [value | gets], updates, into)
    end
  end

  defp do_all_keys([], _next, gets, updates, into) do
    {:lists.reverse(gets), :lists.reverse(updates) |> Enum.into(into)}
  end

  @doc """
  Be able to access any key except some key you want to skip in a Map or a Keyword list through the Access protocol

  ## Examples

      iex> get_in(%{a: %{b: 1}, c: %{b: 2}, d: %{b: 3}}, [EnhancedAccess.skip_keys([:d]), :b])
      [1, 2]

      iex> get_in(%{a: %{b: 1}, c: %{b: 2}, d: %{b: 3}}, [EnhancedAccess.skip_keys([:d])])
      [%{b: 1}, %{b: 2}]

      iex> get_in([a: %{b: 1}, c: %{b: 2}, d: %{b: 3}], [EnhancedAccess.skip_keys([:d])])
      [%{b: 1}, %{b: 2}]

      iex> deeper_nesting = %{a: %{b: %{c: 1}}, d: %{b: %{c: 2}}}
      iex> get_in(deeper_nesting, [EnhancedAccess.skip_keys([:d]), :b,  :c])
      [1]

      iex> update_in(%{a: %{b: 1}, c: %{b: 2}, d: %{b: 3}}, [EnhancedAccess.skip_keys([:d]), :b], &(&1 + 1))
      %{a: %{b: 2}, c: %{b: 3}, d: %{b: 3}}

      iex> update_in([a: %{b: 1}, c: %{b: 2}, d: %{b: 3}], [EnhancedAccess.skip_keys([:d]), :b], &(&1 + 1))
      [a: %{b: 2}, c: %{b: 3}, d: %{b: 3}]

      iex> update_in([a: [b: 1], c: [b: 2], d: [b: 3]], [EnhancedAccess.skip_keys([:d]), :b], &(&1 + 1))
      [a: [b: 2], c: [b: 3], d: [b: 3]]

      iex> get_and_update_in(%{a: %{b: 1}, c: %{b: 2}, d: %{b: 3}}, [EnhancedAccess.skip_keys([:d]), :b], &{&1, &1 + 1})
      {[1, 2], %{a: %{b: 2}, c: %{b: 3}, d: %{b: 3}}}

      iex> pop_in(%{a: %{b: 1}, c: %{b: 2}, d: %{b: 3}}, [EnhancedAccess.skip_keys([:d]), :b])
      {[1, 2], %{a: %{}, c: %{}, d: %{b: 3}}}
  """
  @spec skip_keys(keys :: list) ::
          Access.access_fun(data :: Access.container(), current_value :: term)
  def skip_keys(keys) when is_list(keys) do
    &skip_keys(&1, &2, &3, keys)
  end

  defp skip_keys(:get, data, next, keys) when is_map(data) or is_list(data) do
    data
    |> Enum.reject(fn {key, _} -> key in keys end)
    |> Enum.map(fn {_, value} -> next.(value) end)
  end

  defp skip_keys(:get_and_update, data, next, keys) when is_map(data) do
    do_skip_keys(Map.to_list(data), next, _gets = [], _updates = [], %{}, keys)
  end

  defp skip_keys(:get_and_update, data, next, keys) when is_list(data) do
    do_skip_keys(data, next, _gets = [], _updates = [], [], keys)
  end

  defp do_skip_keys([{key, value} | rest], next, gets, updates, into, keys) do
    if key in keys do
      do_skip_keys(rest, next, gets, [{key, value} | updates], into, keys)
    else
      case next.(value) do
        {get, update} ->
          do_skip_keys(rest, next, [get | gets], [{key, update} | updates], into, keys)

        :pop ->
          do_skip_keys(rest, next, [value | gets], updates, into, keys)
      end
    end
  end

  defp do_skip_keys([], _next, gets, updates, into, _keys) do
    {:lists.reverse(gets), :lists.reverse(updates) |> Enum.into(into)}
  end

  @doc """
  Allow for optional keys in the Access protocol

  ## Examples

      iex> get_in(%{a: %{b: 1}, c: 1}, [EnhancedAccess.all_keys(), EnhancedAccess.optional_key(:b)])
      [1, nil]

      iex> get_in(%{a: 1, c: %{b: 1}}, [EnhancedAccess.all_keys(), EnhancedAccess.optional_key(:b)])
      [nil, 1]

      iex> deeper_nesting = %{a: %{b: %{c: 1}}, d: %{b: %{c: 2}}, e: %{d: 1}}
      iex> get_in(deeper_nesting, [EnhancedAccess.all_keys(), EnhancedAccess.optional_key(:b), :c])
      [1, 2, nil]

      iex> update_in(%{a: %{b: 1}, c: %{d: 2}}, [EnhancedAccess.all_keys(), EnhancedAccess.optional_key(:b)], &(&1 + 1))
      %{a: %{b: 2}, c: %{d: 2}}

      iex> update_in([a: [b: 1], c: [d: 2]], [EnhancedAccess.all_keys(), EnhancedAccess.optional_key(:b)], &(&1 + 1))
      [a: [b: 2], c: [d: 2]]

      iex> get_and_update_in(%{a: %{b: 1}, c: %{d: 2}}, [EnhancedAccess.all_keys(), EnhancedAccess.optional_key(:b)], &{&1, &1 + 1})
      {[1, nil], %{a: %{b: 2}, c: %{d: 2}}}

      iex> pop_in(%{a: %{b: 1}, c: %{d: 2}}, [EnhancedAccess.all_keys(), EnhancedAccess.optional_key(:b)])
      {[1, nil], %{a: %{}, c: %{d: 2}}}
  """
  @spec optional_key(term) :: Access.access_fun(data :: Access.container(), current_value :: term)
  def optional_key(key) do
    &optional_key(&1, &2, &3, key)
  end

  defp optional_key(:get, data, next, key) when is_map(data) do
    value = Map.get(data, key)

    if is_nil(value) do
      nil
    else
      next.(value)
    end
  end

  defp optional_key(:get, data, next, key) when is_list(data) do
    value = Keyword.get(data, key)

    if is_nil(value) do
      nil
    else
      next.(value)
    end
  end

  defp optional_key(:get, _data, _next, _key) do
    nil
  end

  defp optional_key(:get_and_update, data, next, key) when is_map(data) do
    value = Map.get(data, key)

    if is_nil(value) do
      {nil, data}
    else
      case next.(value) do
        {get, update} -> {get, Map.put(data, key, update)}
        :pop -> {value, Map.delete(data, key)}
      end
    end
  end

  defp optional_key(:get_and_update, data, next, key) when is_list(data) do
    value = Keyword.get(data, key)

    if is_nil(value) do
      {nil, data}
    else
      case next.(value) do
        {get, update} -> {get, Keyword.put(data, key, update)}
        :pop -> {value, Keyword.delete(data, key)}
      end
    end
  end

  defp optional_key(:get_and_update, data, _next, _key) do
    {nil, data}
  end
end
