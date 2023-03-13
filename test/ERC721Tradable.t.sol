// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "std/test.sol";
import "../src/ERC721Tradable.sol";

contract ERC721TradableTest is Test{
    ERC721Tradable public myContract;

    address chris = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    address alan = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
   
    

    function setUp() public {
        myContract = new ERC721Tradable("Name", "Symbol");
        myContract.safeTransferFrom(address(this), chris, 1);
        assertEq(myContract.ownerOf(1), address(chris), "");
        vm.deal(chris, 1 ether);
        vm.deal(alan, 1 ether);

    }

    function testSetForSale() public {
        uint256 price = 1 ether;

        // Chris set token 1 price 
        vm.prank(chris);
        myContract.setForSale(1, price);
        assertTrue(myContract.isSetForSale(1));
        assertEq(myContract.getPrice(1), price, "Price mismatch");

        // Alan tries to set price on Chris token 1 and reverts
        vm.prank(alan);
        vm.expectRevert();
        myContract.setForSale(1, price);

        /** Chris set token 1 once again, but to 0. 
         *  Expect isSetForSale(1) to return false   */

        vm.prank(chris);
        myContract.setForSale(1, 0);
        assertFalse(myContract.isSetForSale(1));
        assertEq(myContract.getPrice(1), 0, "Price mismatch");
    }

    function testBuy() public {
        uint256 price = 1 ether;
        // Chris set token 1 price 
        vm.prank(chris);
        myContract.setForSale(1, price);
        assertTrue(myContract.isSetForSale(1));
        assertEq(myContract.getPrice(1), price, "Price mismatch");

        // Alan calls buy with mismatched value
        vm.prank(alan);
        vm.expectRevert();
        myContract.buy{value: 0}(1);


        /** Alan buy token 1 from Chris with msg.value equal to price
        *  Price resets to 0 thus returning false on isSetForSale(1) */
        vm.prank(alan);
        myContract.buy{value: price}(1);
        assertTrue(myContract.ownerOf(1) == alan);
        assertFalse(myContract.isSetForSale(1));
        assertEq(myContract.getPrice(1), 0, "Price mismatch");

        // Chris try to set price again while being previous owner 
        vm.prank(chris);
        vm.expectRevert();
        myContract.setForSale(1, price);

        // Chris try to buy while price is not set
        vm.prank(chris);
        vm.expectRevert();
        myContract.buy{value: price}(1);

        
    }

    function testCallRevert() public {
        uint256 price = 1 wei;
        // Chris sets price on token 1
        vm.prank(chris);
        myContract.transferFrom(chris, address(this), 1);
        vm.stopPrank();

        myContract.setForSale(1, price);
        //  expect ether call() revert due to revert() on this contract
        vm.prank(chris);
        vm.expectRevert("failed to send eth");
        myContract.buy{value: price}(1);
        
    }


    function testSupportInterface() public {
        // Support ERC721 Tradable interface
        assertTrue(myContract.supportsInterface(0xbdb98cf0));
        // Support ERC721 interface
        assertTrue(myContract.supportsInterface(0x80ac58cd));
    }
    

    function testApprovedOrOwner()  public {
        vm.prank(address(myContract));
        myContract.safeTransferFrom(chris, alan, 1);
    }

    receive() external payable{
        revert();
    }
   


}