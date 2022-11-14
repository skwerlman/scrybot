# This file modified from https://github.com/pmarreck/elixir-snippets/blob/master/damerau_levenshtein.exs
# The below license notice applies to this file in its entirety,
# and supercedes the repo license in case of conflicts.

# Copyright (c) 2014, Peter Marreck
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of elixir-snippets nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# attempt to calculate damerau-levenshtein equivalence of 2 strings with distance k

defmodule Scrybot.DamerauLevenshtein do
  @moduledoc """
  Compute whether the damerau-levenshtein distance between 2 strings is at or below k (cost).
  This entails tallying the total cost of all insertions, deletions, substitutions and transpositions
  """
  @spec equivalent?(String.t(), String.t(), integer()) :: boolean()
  @spec distance(String.t(), String.t()) :: integer()
  @spec distance(String.t(), String.t(), integer()) :: integer()
  @spec distance(String.t(), String.t(), integer(), integer()) :: integer()

  @doc """
  Test for Damerau-Levenshtein equivalency, given two strings and a k (cost/distance) value.
  """
  def equivalent?(candidate, target, k) do
    distance(candidate, target, k) <= k
  end

  # initialize current_cost state
  def distance(a, b, max \\ 10) do
    distance(a, b, max, 0)
  end

  # current_cost exceeds max_cost
  def distance(_, _, max_cost, current_cost) when current_cost > max_cost do
    # can't error or raise here since other recursions may find smaller costs, so just return max+1
    # also because the distance function is expected to return an integer.
    max_cost + 1
  end

  # empty strings
  def distance("", "", _max_cost, current_cost) do
    # IO.puts "Remaining strings empty"
    current_cost
  end

  def distance("", b, _max_cost, current_cost) do
    current_cost + String.length(b)
  end

  def distance(a, "", _max_cost, current_cost) do
    current_cost + String.length(a)
  end

  # two equivalent strings
  def distance(same, same, _max_cost, current_cost) do
    # IO.puts "Remaining strings the same: #{same}"
    current_cost
  end

  # if both heads are the same, advance both
  def distance(
        <<equal_char::utf8, candidate_tail::binary>>,
        <<equal_char::utf8, target_tail::binary>>,
        max_cost,
        current_cost
      ) do
    # IO.puts "Both chars same: '#{equal_char}' Advancing both"
    distance(candidate_tail, target_tail, max_cost, current_cost)
  end

  # heads are different, but a transposition is in place. advance both and increment cost by 1
  def distance(
        <<first_char::utf8, second_char::utf8, candidate_tail::binary>>,
        <<second_char::utf8, first_char::utf8, target_tail::binary>>,
        max_cost,
        current_cost
      ) do
    # IO.puts "Transposition seen between #{first_char}#{second_char} and #{second_char}#{first_char}."
    distance(candidate_tail, target_tail, max_cost, current_cost + 1)
  end

  # heads are different, assume a substitution OR 1 deletion in either side
  # (an insertion relative to the other side) and return minimum value of all costs.
  # Note that this is where runtimes can get hairy in worst cases, there's no TCO here
  def distance(
        whole_candidate = <<_candidate_head::utf8, candidate_tail::binary>>,
        whole_target = <<_target_head::utf8, target_tail::binary>>,
        max_cost,
        current_cost
      ) do
    Enum.min([
      # substitution of character
      distance(candidate_tail, target_tail, max_cost, current_cost + 1),
      # single deletion in candidate (insertion in target)
      distance(candidate_tail, whole_target, max_cost, current_cost + 1),
      # single deletion in target (insertion in candidate)
      distance(whole_candidate, target_tail, max_cost, current_cost + 1)
    ])
  end
end
