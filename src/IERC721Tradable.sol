// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional tradable extension
 */
interface IERC721Tradable is IERC721 {
    /**
     * @dev Returns true if the token is set for sale.
     */
    function isSetForSale(uint256 tokenId) external view returns (bool);

    /**
     * @dev Returns the token price in wei.
     */
    function getPrice(uint256 tokenId) external view returns (uint256 price);

    /**
     * @dev Sets `price` for `tokenId`.
     * Caller set {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The caller MUST be the owner.
     *
     * Emits an {SetForSale} event.
     */
    function setForSale(uint256 tokenId, uint256 price) external;

    /**
     * @dev Buy `tokenId` for the required amount of eth.
     * Caller can buy if {isSetForSale} returns true.
     *
     * Requirements:
     *
     * - The caller MUST NOT be the owner.
     * - The msg.value MUST be EQUAL to returned price from {getPrice}.
     *
     * Emits {Buy} event.
     */
    function buy(uint256 tokenId) external payable; 
}
