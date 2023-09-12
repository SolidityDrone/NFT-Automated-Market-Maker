## Yakiswap protocol 

This is an experimental Autameted Market Maker based off NFTs.
Users can create his own pool and provide either liquidity, assets or both. They can setup parameters to manage the behaviour of the AMM.
This is intended to work in pair with a TheGraph subgraph as most events from main contract are emitted to not waste any further gas on storage. 

## Quick structure explaination 

The user(provider) can set up his own pool, which is basically a contract deployed via create2 which can hold nfts. This contract will store the parameters and will deal trustlessy the transactions whenever an user(buyer) sets an order


This project is live on polygon testnet at 0x89c97F13c22224129D4A4820813DE4a7c0a954e6.
As front end is still WIP consider this work just as a reference whenever you feel like making use of it 

