### A Pluto.jl notebook ###
# v0.18.4

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ f65a01a2-31df-4445-9a3d-3bb3105113d8
begin
	using Pkg
	Pkg.activate(pwd())
	Pkg.add(path="/home/vikas/Desktop/Julia_training/GitHub_collab/BTCParser.jl")
	Pkg.add("DataFrames")
    Pkg.add("VegaLite")
	Pkg.add("PlutoUI")	
end

# ╔═╡ 101ce66d-9c3a-41a8-a0ed-7c2c6c6929ed
begin
	Pkg.add("Query")
	using Query, Statistics
end

# ╔═╡ 759eca19-a79f-43f7-ae34-bd9e8991b198
begin
	Pkg.add("BenchmarkTools")
	using BenchmarkTools
end

# ╔═╡ a628bf59-823f-47e9-ac19-e26dfa87a19f
using BTCParser, DataFrames, VegaLite, PlutoUI, Dates

# ╔═╡ a3c994b5-26fc-43c1-915c-3b77bd55574a
md" > **Author: Vikas Negi**
>
> [LinkedIn] (https://www.linkedin.com/in/negivikas/)
"

# ╔═╡ 8209bb38-36b1-4309-b33e-f5c91f9fc01a
md"
### Load packages
---
"

# ╔═╡ 5fb90837-8d28-46f8-a911-8e7a72e01a84
md"
[BTCParser.jl](https://github.com/gdkrmr/BTCParser.jl) is not yet registered. You will therefore need to add the package explicitly as shown below. I have also hardcoded the path to my Bitcoin blockchain data directory within the package source code.
"

# ╔═╡ db629dfc-2662-4c30-93dd-79fa085b4272
md"
### Get blockchain data
---
"

# ╔═╡ 1c7333d8-0b17-42da-86fc-4d3d4dabf528
md"
##### Parse blocks

Parsing will be done on the blk*.dat files present within the **blocks** folder. The current size of this directory is ~ 424 GB (checked on 11-04-2022) and is only expected to grow as time progresses.

My PC is equipped with a PCIe gen3 NVMe SSD. The disk IO is therefore quite fast! Even with that, it took about 10-12 minutes to parse through all the data.
"

# ╔═╡ 8885beb3-5cbc-4159-86e5-63134649bb08
chain = make_chain()

# ╔═╡ c90c1e0b-ba39-4bae-b56e-af7ecf964b01
md"
We can iterate through the `chain` object of type `BTCParser.Chain`, which is quite handy to gather statistics over a selection of blocks.
"

# ╔═╡ ffac62f0-8cbb-4914-8027-78b5fdf67711
chain[1]

# ╔═╡ fd4cb49b-96bc-4b97-be13-32a48120de56
typeof(chain)

# ╔═╡ a96489a4-a18b-4386-a932-013506aefc6c
md"
Size of chain is equal to the number of blocks for which the data is found. The size would increase if we keep syncing the local node since a new block is added roughly every 10 minutes.
"

# ╔═╡ 924c7a5f-61b3-4066-a8c3-08968b8f4414
length(chain)

# ╔═╡ e0871acc-e04b-4e47-8986-83f1c3395d88
md"
##### Block information
"

# ╔═╡ 4701a3ba-19ed-41d0-9ca6-9d8cd607d27c
Block(chain[600000])

# ╔═╡ 5b856c2c-769b-41ba-819a-c00ce2027f5c
md"
##### Collect block data

By iterating through a selection of blocks, we can gather information about the timestamp, difficulty, number of transactions and total transacted value. This is best stored in the form of a DataFrame.
"

# ╔═╡ f46df689-157e-46c3-9995-2695cdca206b
md"
##### Total transacted value

This value is obtained by summing over all the outputs in a given block.
"

# ╔═╡ e496c391-af1d-4523-9dbe-1b0caba40921
function get_total_tx_value(block::Block)

	num_tx = length(block.transactions)
	output_per_tx = Int64[]

	for i = 1:num_tx
		num_outputs = length(block.transactions[i].outputs)

		output_amount = 0
		for j = 1:num_outputs
			output_amount += convert(Int64, 
				                     block.transactions[i].outputs[j].amount)
		end

		push!(output_per_tx, output_amount)
	end

	output_per_block = sum(output_per_tx)

	# Convert Satoshis to BTC
	return round(output_per_block/1e8, digits = 2)
end			

# ╔═╡ edf1894f-38aa-48d8-8996-e8c3d8916135
function get_block_data(chain::BTCParser.Chain, b_start::Int64, b_end::Int64)

	@assert b_end ≤ length(chain) "Not enough blocks"

	timestamps   = DateTime[]
	difficulties, transactions = Int64[], Int64[]
	tx_value, block_rewards    = Float64[], Float64[]

	for i = b_start:b_end

		block_data = Block(chain[i])
		convert_data(x) = convert(Int64, x)
		
		time = block_data.header.timestamp |> convert_data
		diff = block_data.header.difficulty_target |> convert_data
		tx   = block_data.transaction_counter |> convert_data
		block_reward = block_data.transactions[1].outputs[1].amount |> convert_data
		
		tx_per_block = get_total_tx_value(block_data)

		push!(timestamps, unix2datetime(time))
		push!(difficulties, diff)
		push!(transactions, tx)
		push!(block_rewards, round(block_reward/1e8, digits = 2))
		push!(tx_value, tx_per_block)

	end

	df_blocks = DataFrame(tstamp = timestamps, diff = difficulties, 
		                  tx = transactions, tx_value = tx_value,
	                      block_rewards = block_rewards)

	return df_blocks
end	

# ╔═╡ afc1ba23-a5e1-4373-bf89-4f7931326a8e
df_blocks = get_block_data(chain, 400000, 729900)

# ╔═╡ 3bf6c083-0879-4ca8-a7b8-a180df947a7b
md"
##### Block hash

The block hash is calculated by hashing all the data in the Block Header through SHA-256.
"

# ╔═╡ 0e08e254-590f-492d-9244-be3740bb623c
double_sha256(Block(chain[456782]))

# ╔═╡ 078a26bd-7b0f-4970-95b0-0db0ae6bc54f
md"
### Visualize data
---
"

# ╔═╡ 72bb07a4-a303-4e5a-8d91-0792146c45ea
md"
##### Get daily data

Our original DataFrame contains blocks with a time interval of ~ 10 minutes. For visualization, it makes more sense to look at daily time intervals. Therefore, we can combine the block data for a given day and create a new DataFrame.
"

# ╔═╡ 6cd8644a-694e-42db-aae4-a7f9cd2c914f
function get_daily_data(df_blocks::DataFrame)

	rows, cols = size(df_blocks)
	j = 1
	day = Date[]
	tx_per_day, diff_per_day  = [Int64[] for i = 1:2]	
	tx_value_per_day = Float64[]

	for i = 2:rows

		# Loop up to the point when date changes, then sum all the entries till then
		if Dates.Date(df_blocks[!, :tstamp][i]) != 
		   Dates.Date(df_blocks[!, :tstamp][i - 1])

			tx_sum    = sum(df_blocks[!, :tx][j:i - 1])
			diff_mean = Statistics.mean(df_blocks[!, :diff][j:i - 1])
			tx_value_sum = sum(df_blocks[!, :tx_value][j:i - 1])

			push!(day, Dates.Date(df_blocks[!, :tstamp][i - 1]))
			push!(tx_per_day, tx_sum)
			push!(diff_per_day, round(Int64, diff_mean))
			push!(tx_value_per_day, tx_value_sum)

			j = i

		end

		# When counter reaches the last day
		if i == rows
			
			tx_sum = sum(df_blocks[!, :tx][j:i])
			diff_mean = Statistics.mean(df_blocks[!, :diff][j:i])
			tx_value_sum = sum(df_blocks[!, :tx_value][j:i])
			
			push!(day, Dates.Date(df_blocks[!, :tstamp][i - 1]))
			push!(tx_per_day, tx_sum)
			push!(diff_per_day, round(Int64, diff_mean))
			push!(tx_value_per_day, tx_value_sum)
		end
	end

	df_blocks_per_day = DataFrame(tstamp = day, diff = diff_per_day, 
	                             tx = tx_per_day, tx_value = tx_value_per_day)

	return df_blocks_per_day
end

# ╔═╡ 52924ee2-8927-4bfe-a96d-8e5b0cd0d958
df_blocks_per_day = get_daily_data(df_blocks)

# ╔═╡ e102d646-c47a-429c-b37f-442fd9ccc57d
md"
##### Filter on time range
"

# ╔═╡ 344079e2-7913-439c-ac29-8459cadddf76
@bind start_date DateField(default = DateTime(2016,1,1))

# ╔═╡ 9c471423-1539-40ed-8fd5-6fe26c1adea7
@bind end_date DateField(default = DateTime(2022,04,01))

# ╔═╡ 2e302651-5893-4d00-ac0f-f76dd4e7aa3e
df_blocks_filter = df_blocks_per_day |> 

@filter(_.tstamp > start_date &&  _.tstamp < end_date) |> DataFrame

# ╔═╡ 104e6578-f0cf-4994-bbe5-c78780b55919
md"
##### Maximum transaction value on a given day
"

# ╔═╡ 9abcaab6-87d6-43dc-9618-6ffccbe78b1c
df_blocks_filter |> @filter(_.tx_value == maximum(df_blocks_filter[!, :tx_value]))

# ╔═╡ 7a4f2914-b49e-49f5-8dcd-743915012752
md"
##### Number of transactions
"

# ╔═╡ 30e927c8-6da6-4665-9ce3-cd5d1b0126e4
figure1 = df_blocks_filter |> 

@vlplot(mark={:line, interpolate = "monotone"}, 
	x = {:tstamp, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}, "type" = "temporal"}, 
	y = {:tx, "axis" = {"title" = "Number of transactions", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 800, height = 500, 
	"title" = {"text" = "Number of transactions between $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16})

# ╔═╡ 9eef762a-174c-42c3-bc87-b0c5034aa9cc
md"
##### Total transacted value
"

# ╔═╡ d2da1ea6-974d-4b54-810b-2fad814cc273
figure2 = df_blocks_filter |> 

@vlplot(mark = {:line, interpolate = "monotone"}, 
	x = {:tstamp, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}, "type" = "temporal"}, 
	y = {:tx_value, "axis" = {"title" = "Transacted value [BTC]", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 750, height = 500, 
	"title" = {"text" = "Per day transaction value between $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16})

# ╔═╡ 0e5b15e8-9318-4e6d-bf36-c6b528cc8a4c
md"
##### Average block time

Using the timestamps, we can calculate the amount of time elapsed between consecutive blocks. The Bitcoin network adjusts its diffculty such that a block is generated on an average in ~ 10 minutes. Since difficulty adjustment is not instantaneous, there  are blocks with shorter or longer duration as well. Blocks will be generated faster when the network hashrate increases significantly and difficulty is gradually readjusting to a higher value. On the contrary, a sudden dip in the network hashrate will increase block generation time until the difficulty readjusts to a lower value.
"

# ╔═╡ 0adbb794-5094-4a66-ae71-c3646d6cf636
function get_block_tstamps(df_blocks::DataFrame)

	block_tstamps = df_blocks[!, :tstamp][2:end] - df_blocks[!, :tstamp][1:end-1]
	block_mins    = [block_tstamps[i].value / 60000 for i in eachindex(block_tstamps)]

	return DataFrame(block_mins = block_mins)
end	

# ╔═╡ fb15df5b-e024-44b0-8d44-4e2274477f8d
@btime get_block_tstamps(df_blocks);

# ╔═╡ 8f5c4bda-16c8-48a2-90f0-43f54e2eadbb
figure3 =  get_block_tstamps(df_blocks) |> 
	
@vlplot(:bar, 
	x = {:block_mins, "bin" = {"maxbins" = 25}, "axis" = {"title" = "Block time [mins]", "labelFontSize" = 12, "titleFontSize" = 14}}, 
	y = {"count()", "axis" = {"title" = "Number of counts", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 750, height = 500, 
	"title" = {"text" = "Distribution of BTC block times", "fontSize" = 16})

# ╔═╡ b903dd3f-f52e-455e-8c0b-0b5dc93af4a1
md"
##### Block reward halving
"

# ╔═╡ c20f28f7-2925-46ed-98f8-f8f63fc3bbc8
convert(Int64, Block(chain[600000]).transactions[1].outputs[1].amount)

# ╔═╡ Cell order:
# ╟─a3c994b5-26fc-43c1-915c-3b77bd55574a
# ╟─8209bb38-36b1-4309-b33e-f5c91f9fc01a
# ╟─5fb90837-8d28-46f8-a911-8e7a72e01a84
# ╠═f65a01a2-31df-4445-9a3d-3bb3105113d8
# ╠═a628bf59-823f-47e9-ac19-e26dfa87a19f
# ╟─db629dfc-2662-4c30-93dd-79fa085b4272
# ╟─1c7333d8-0b17-42da-86fc-4d3d4dabf528
# ╠═8885beb3-5cbc-4159-86e5-63134649bb08
# ╟─c90c1e0b-ba39-4bae-b56e-af7ecf964b01
# ╠═ffac62f0-8cbb-4914-8027-78b5fdf67711
# ╠═fd4cb49b-96bc-4b97-be13-32a48120de56
# ╟─a96489a4-a18b-4386-a932-013506aefc6c
# ╠═924c7a5f-61b3-4066-a8c3-08968b8f4414
# ╟─e0871acc-e04b-4e47-8986-83f1c3395d88
# ╠═4701a3ba-19ed-41d0-9ca6-9d8cd607d27c
# ╟─5b856c2c-769b-41ba-819a-c00ce2027f5c
# ╟─edf1894f-38aa-48d8-8996-e8c3d8916135
# ╟─f46df689-157e-46c3-9995-2695cdca206b
# ╟─e496c391-af1d-4523-9dbe-1b0caba40921
# ╠═afc1ba23-a5e1-4373-bf89-4f7931326a8e
# ╟─3bf6c083-0879-4ca8-a7b8-a180df947a7b
# ╠═0e08e254-590f-492d-9244-be3740bb623c
# ╟─078a26bd-7b0f-4970-95b0-0db0ae6bc54f
# ╟─101ce66d-9c3a-41a8-a0ed-7c2c6c6929ed
# ╟─72bb07a4-a303-4e5a-8d91-0792146c45ea
# ╟─6cd8644a-694e-42db-aae4-a7f9cd2c914f
# ╠═52924ee2-8927-4bfe-a96d-8e5b0cd0d958
# ╟─e102d646-c47a-429c-b37f-442fd9ccc57d
# ╠═344079e2-7913-439c-ac29-8459cadddf76
# ╠═9c471423-1539-40ed-8fd5-6fe26c1adea7
# ╠═2e302651-5893-4d00-ac0f-f76dd4e7aa3e
# ╟─104e6578-f0cf-4994-bbe5-c78780b55919
# ╠═9abcaab6-87d6-43dc-9618-6ffccbe78b1c
# ╟─7a4f2914-b49e-49f5-8dcd-743915012752
# ╠═30e927c8-6da6-4665-9ce3-cd5d1b0126e4
# ╟─9eef762a-174c-42c3-bc87-b0c5034aa9cc
# ╠═d2da1ea6-974d-4b54-810b-2fad814cc273
# ╟─0e5b15e8-9318-4e6d-bf36-c6b528cc8a4c
# ╠═759eca19-a79f-43f7-ae34-bd9e8991b198
# ╟─0adbb794-5094-4a66-ae71-c3646d6cf636
# ╠═fb15df5b-e024-44b0-8d44-4e2274477f8d
# ╠═8f5c4bda-16c8-48a2-90f0-43f54e2eadbb
# ╟─b903dd3f-f52e-455e-8c0b-0b5dc93af4a1
# ╠═c20f28f7-2925-46ed-98f8-f8f63fc3bbc8
