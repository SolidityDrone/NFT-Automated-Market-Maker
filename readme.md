## Abstract 
This is an extension of ERC721 that allows token trading with an assigned price. It includes functions for setting a token for sale, checking if a token is on sale, and buying a token.

## Context
This extension allows for token owner to set a price directly on the nft thus allowing to make a p2p sale without the need of an intermediary to trust.
The owner dosen't have to set approval to any contract and keeps custody of the token untill it's sold.
This is ideal for a marketplace that dosen't involve off-chain tasks to keep track of prices of the nft that are listed and easily allows onchain sales by contracts.

This of course can be done by Opensea aswell through their APIs but that requires a fee. 

## Specification 
This extension proposes two sided interaction 
- Seller can set price on token and it's ready for sale
- Buyer pays ethers to buy the token

## Interface 
```

interface IERC721Tradable is IERC721 {
 
    function isSetForSale(uint256 tokenId) external view returns (bool);

    function getPrice(uint256 tokenId) external view returns (uint256 price);

    function setForSale(uint256 tokenId, uint256 price) external;

    function buy(uint256 tokenId) external payable; 
}

```

## Easy third-Party integration 

Any GUI can simply create transactions to prompt transactions for both users in a simple way

## Backwards Compatibility

A contract that extends ERC721 with this interface will be backward compatible. Any approach that works with normal ERC721 are still viable and secured since this interface dosen't really change the logic behind ERC721
It only adds up few functions 

## Reference Implementation 


```
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IERC721Tradable.sol";


contract ERC721Tradable is ERC721, IERC721Tradable {

    
    event SetForSale(
        address indexed owner,
        uint256 indexed price,
        uint256 indexed tokenId
    );

  
    event Buy(
        address indexed owner,
        address indexed buyer,
        uint256 indexed tokenId
    );

    mapping(uint256 => uint256) internal _prices;

    constructor(string memory name_, string memory symbol_) ERC721(name_,symbol_) {
    }

    function isSetForSale(uint256 tokenId) external view virtual override returns (bool) {
        return _isSetForSale(tokenId);
    }

 
    function _isSetForSale(uint256 tokenId) internal view returns (bool){
        return _prices[tokenId] > 0 ;
    }

    function getPrice(uint256 tokenId) external view virtual override returns (uint256) {
        return _prices[tokenId];
    }

    function setForSale(uint256 tokenId, uint256 amount) external virtual override {
        require(msg.sender == ownerOf(tokenId), "ERC721Tradable: not owner");
        _prices[tokenId] = amount;
        emit SetForSale(msg.sender, amount, tokenId);
    }


    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC721Tradable).interfaceId || super.supportsInterface(interfaceId);
    }


    function buy(uint256 tokenId) external payable override {
        uint256 price = _prices[tokenId];
        require(_isSetForSale(tokenId), "ERC721Tradable: token not on sale");
        require(msg.value == price, "ERC721Tradable: incorrect value");

        address buyer = msg.sender;
        address owner = ownerOf(tokenId);

        _safeTransfer(owner, buyer, tokenId, "");

        (bool sent, ) = owner.call{value: msg.value}("");
        require(sent, "failed to send eth");

        emit Buy(owner, buyer, tokenId);
    }


    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
        if (spender == address(this)){
           return true;
        }
        return  super._isApprovedOrOwner(spender, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        delete _prices[tokenId];
    }
}
```
    
Owner of token can setForSale(uint256 tokenId, uint256 amount) to enable for sale. When amount is 0 the item is not on sale and can be checked through isSetForSale(uint256 tokenId) view function.
The contract will always return true when checked as spender in  _isApprovedOrOwner(spender, to).

The buyer can then call Buy() function. This is a payable function and the amount of ethers sent in wei must match  _prices[tokenId]  

When a token is sold or just transfered for any reason, the price is reset to 0 through _beforeTokenTransfer in order to prevent the new holder to inherit the previous sale conditions.

## Security Consideration 
This implementation is tested and buy function is protected from reentrancy, keep in mind that you could also import reentrancyGuard from @openzeppelin repo and add nonReentrant modifer to the function, especially if you change something in that current implementation

## Test 

Test are written within foundry, to run tests first you need to install foundry on your machine.

Once you installed it you can test the code by running: 

```
forge test -vvv
```
and / or 

```
forge coverage
```
| File                   | % Lines         | % Statements    | % Branches      | % Funcs       |
|------------------------|-----------------|-----------------|-----------------|---------------|      
| src/ERC721Tradable.sol | 100.00% (20/20) | 100.00% (22/22) | 100.00% (10/10) | 100.00% (8/8) |      
| Total                  | 100.00% (20/20) | 100.00% (22/22) | 100.00% (10/10) | 100.00% (8/8) |   

