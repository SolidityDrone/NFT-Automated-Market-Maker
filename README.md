## Yakiswap protocol 

This is an experimental Autameted Market Maker based off NFTs.
Users can create his own pool and provide either liquidity, assets or both. They can setup parameters to manage the behaviour of the AMM.
This is intended to work in pair with a TheGraph subgraph as most events are emitted to not waste any further gas on storage. 
Refer to https://www.hadeswap.com/ (Solana) to get an idea of how AMM works for NFTs 

## Quick Overview
 
This contract is structured as follows:
  A main contract which deals with the creation of other contracts via CREATE2.
  Factory contracts acting as pool.

Whenever an user(provider) creates a pool a new contract is generated. Users(buyers/sellers) can then interact trustlessy with a pool to make their transactions.

## WEN 
This project is WIP, currently live at 0x89c97F13c22224129D4A4820813DE4a7c0a954e6 -Polygon testnet
