## BTC_blockchain_analysis

In this Pluto notebook, we will parse and analyze the Bitcoin blockchain data. To do so, first you
need to run a full node using [Bitcoin Core](https://bitcoin.org/en/bitcoin-core/). The software 
will download a copy of the blockchain onto your disk. Keep in mind that you need about 424 GB
space (as of 11-04-2022) in case you want the blocks until the latest height. You can also stop
the sync earlier, in that case, you will only have data until that specific point of time. This is
the recommended way to get authentic and reliable data. It's wise not to trust any other sources.
If you are really impatient, you can always copy over the data from a trusted friend's local
node.

The intial sync can be quite demanding. On my desktop PC equipped with a Ryzen 5 3600, fast PCIe
gen3 NVMe SSD and 32 GB of RAM (16 GB allocated to Bitcoin Core's dbcache to speed up sync), it
took about four hours to reach the latest block height. 

## How to use?

Install Pluto.jl (if not done already) by executing the following commands in your Julia REPL:

    using Pkg
    Pkg.add("Pluto")
    using Pluto
    Pluto.run() 

Clone this repository and open BTC_blocks_notebook.jl in your Pluto browser window. You will need
to tell BTCParser.jl as to where the blockchain data is stored. In my case, I hardcoded the `DIR`
constant (in the module definition file within my local copy of package) to point to the data 
directory.