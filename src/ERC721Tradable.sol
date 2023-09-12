// SPDX-License-Identifier: MIT
// Author: SolidityDrone
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IERC721Tradable.sol";

/**
 * @title ERC721Tradable
 * @dev Extends ERC721 implementation to support token trading with an assigned price.
 */
contract ERC721Tradable is ERC721, IERC721Tradable {

    // Event emitted when a token is set for sale.
    event SetForSale(
        address indexed owner,
        uint256 indexed price,
        uint256 indexed tokenId
    );

    // Event emitted when a token is bought.
    event Buy(
        address indexed owner,
        address indexed buyer,
        uint256 indexed tokenId
    );

    // Mapping of token IDs to their assigned prices.
    mapping(uint256 => uint256) internal _prices;

    /**
     * @dev Constructor that mints a new token and assigns it to the contract owner.
     * @param name_ The name of the ERC721 token.
     * @param symbol_ The symbol of the ERC721 token.
     */
    constructor(string memory name_, string memory symbol_) ERC721(name_,symbol_) {
        //safeMinting for testing purposes
        _mint(msg.sender, 1);
    }

    /**
     * @dev Returns whether a token is set for sale.
     * @param tokenId The ID of the token to check.
     * @return Whether the token is set for sale.
     */
    function isSetForSale(uint256 tokenId) external view virtual override returns (bool) {
        return _isSetForSale(tokenId);
    }

    /**
     * @dev Returns whether a token is set for sale.
     * @param tokenId The ID of the token to check.
     * @return Whether the token is set for sale.
     */
    function _isSetForSale(uint256 tokenId) internal view returns (bool){
        return _prices[tokenId] > 0 ;
    }

    /**
     * @dev Returns the price assigned to a token.
     * @param tokenId The ID of the token to check.
     * @return price assigned to the token.
     */
    function getPrice(uint256 tokenId) external view virtual override returns (uint256) {
        return _prices[tokenId];
    }

    /**
     * @dev Sets the price for a token and emits a SetForSale event.
     * @param tokenId The ID of the token to set the price for.
     * @param amount The price to assign to the token.
     */
    function setForSale(uint256 tokenId, uint256 amount) external virtual override {
        require(msg.sender == ownerOf(tokenId), "ERC721Tradable: not owner");
        _prices[tokenId] = amount;
        emit SetForSale(msg.sender, amount, tokenId);
    }

    /**
     * @dev Overrides the supportsInterface function to include the IERC721Tradable interface.
     * @param interfaceId The ID of the interface to check for support.
     * @return Whether the contract supports the interface.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC721Tradable).interfaceId || super.supportsInterface(interfaceId);
    }


    /**
     * @dev Transfers ownership of a token from the seller to the buyer and emits a Buy event.
     * @param tokenId The ID of the token to buy.
     */
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

    /**
     * @dev Checks if the spender is approved or the owner of the specified token.
     * Overrides the internal function in the ERC721 contract.
     * @param spender The address being checked for approval or ownership.
     * @param tokenId The ID of the token being checked.
     * @return bool Returns true if the spender is approved or the owner of the specified token, otherwise false.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
        if (spender == address(this)){
           return true;
        }
        return  super._isApprovedOrOwner(spender, tokenId);
    }


    /**
     * @dev Called before a token transfer, overrides the internal function in the ERC721 contract.
     * Deletes the price associated with the specified token.
     * @param from The address of the sender.
     * @param to The address of the receiver.
     * @param tokenId The ID of the token being transferred.
     * @param batchSize The number of tokens being transferred in the batch.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        delete _prices[tokenId];
    }
}

    

