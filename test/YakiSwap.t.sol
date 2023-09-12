// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "std/test.sol";
import "../src/mocks/YakiSwapMock.sol";
import "../src/ERC721Mock.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract YakiSwapTest is Test, IERC721Receiver{
    address chris = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    address alan = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    
    ERC721Mock col;
    YakiSwapMock ys;
    Pool pool;

   

    function setUp()public{
        col = new ERC721Mock();
        ys = new YakiSwapMock();
        
        vm.deal(alan, 100e18);
        vm.deal(address(this), 100e18);
        
        for (uint i; i<100; i++){
            vm.prank(address(this));
            col.mint();
        }
        for (uint i; i<10; i++){
            vm.prank(alan);
            col.mint();
        }
      

        assertTrue(ys._implementationPool() != address(0));


        ys.createPool(address(col), 0,0,0,0,true, new uint256[](0));
        pool = Pool(payable(address(ys.getPoolAddress(1))));
        assertTrue(ys._poolCounter() == 2);

    }
    ///// INTERNAL HOOKS
    

    ///// TEST YAKISWAP CONTRACT 
    
    function testPoolCreation() public {
        vm.prank(alan);
        ys.createPool(address(col), 0,0,0,0,true, new uint256[](0));
        address alanPoolAddress = ys.s_Pool_Address_By_ID(2);
        assertTrue(ys.getPoolAddress(2) == alanPoolAddress);
        assertTrue(ys.s_Pool_ID_By_Address(alanPoolAddress) == 2);
        
        Pool alanPool = Pool(payable(address(ys.getPoolAddress(2))));

        assertTrue(alanPool._owner() == alan);
        assertTrue(address(alanPool._collection()) == address(col));
        assertTrue(alanPool._initialized());
        assertTrue(address(alanPool._parent()) == address(ys));

        vm.prank(alan);
        vm.expectRevert("Already initialized");
        alanPool.initialize(alan, address(col));
    }

    function test_internal_incrementCounter() public {
        assertTrue(ys._poolCounter() == 2);
        ys._incrementCounter();
        assertTrue(ys._poolCounter() == 3);
    }

    function testHandlertransfer() public {
        vm.expectRevert("Not Allowed");
        ys.handleTransfer(address(col), address(pool), 1);

        
        col.setApprovalForAll(address(ys), true);
        vm.prank(address(pool));
        ys.handleTransfer(address(col), address(this), 1);

        assertTrue(col.ownerOf(1) == address(pool));
    }
    ///// TEST POOL CONTRACT 

    function testSetPoolProperties() public {
        pool.mock_set_buyCount(5);
        pool.mock_signedCurrentOrder(-5);
        assertTrue(pool._buyCount() == 5 && pool._signedCurrentOrder() == -5);
        vm.prank(alan);
        vm.expectRevert("Pool: not owner");
        pool.setPoolProperties(1e18, type(uint256).max, type(uint16).max, type(uint16).max, true);
        
        pool.setPoolProperties(1e18, type(uint256).max, type(uint16).max, type(uint16).max, true);
        assertTrue(pool._buyCount() == 0 && pool._signedCurrentOrder() == 0);
    }

    function testDepositFunds() public {
        pool.deposit{value: 1e18}(new uint256[](0));
        assertTrue(address(pool).balance == 1e18);
    }

    function testDepositNFT() public {
        col.setApprovalForAll(address(ys), true);
        uint256[] memory tokenArray = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            tokenArray[i] = i + 1;
        }
        pool.deposit(tokenArray);
        assertTrue(col.balanceOf(address(this)) == 90);
        assertTrue(col.balanceOf(address(pool)) == 10);
        assertTrue(pool.getSellOrders() == 10);
        uint256[] memory tokenArray2 = new uint256[](1);
        tokenArray2[0] = 101;
        vm.prank(alan); 
        vm.expectRevert("Pool: not owner");
        pool.deposit(tokenArray);
    }

    
    function testWithdrawFunds() public {
        uint256 startingBalance = address(this).balance;
        pool.deposit{value: 1e18}(new uint256[](0));
        assertTrue(address(pool).balance == 1e18);
        assertTrue(startingBalance - address(this).balance == 1e18);

        vm.prank(alan);
        vm.expectRevert("Pool: not owner");
        pool.withdraw(new uint256[](0), 1e18);

        pool.withdraw(new uint256[](0), 1e18);
        assertTrue(address(this).balance == startingBalance);
    }
    
    function testWithdrawNFT() public {
        col.setApprovalForAll(address(ys), true);
        uint256[] memory tokenArray = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            tokenArray[i] = i + 1;
        }
        pool.deposit(tokenArray);
        

        vm.prank(alan);
        vm.expectRevert("Pool: not owner");
        pool.withdraw(tokenArray,0 );

        pool.withdraw(tokenArray,0);
        assertTrue(col.balanceOf(address(pool)) == 0);
        assertTrue(col.balanceOf(address(this)) == 100);
    }

    




 
    function test_absoluteModule(int256 value) public {
        vm.assume(value > 0);
        assertTrue(pool._absoluteModule(-value) == uint256(value));
        assertTrue(pool._absoluteModule(value) == uint256(value));
        assertTrue(pool._absoluteModule(0) == uint256(0));
    }

   
    function test_Fuzz_Exponential_CalculateOrderPrice(int32 signedCurrentOrder, uint256 price, uint256 delta) public {
        vm.assume(signedCurrentOrder < 1e5  && price < 1e28 && delta < 1e4);  

        assertTrue(pool._calculateOrderPrice(0, price, 0, true) == price);
        assertTrue(pool._calculateOrderPrice(signedCurrentOrder, price, 0, true) == price);
        
        pool._calculateOrderPrice(signedCurrentOrder, price, delta, true);
    }

    function test_Exponential_calculateClamps() public {
        // While delta is 10000 ( 100% ) this function will return 0 when signedCurrentOrder is 0;
        uint256 deltaIs100Percent = 10000; 
        assertTrue(pool._calculateOrderPrice(-1, 1e18, deltaIs100Percent, true) == 0);
        // If the calculation overflows due to high signedCurrentOrder and Delta it returns uint256 max value
        assertTrue(pool._calculateOrderPrice(10000, 1e18, deltaIs100Percent, true) == type(uint256).max);
    }


    function test_Exponential_OrderPriceOutPut() public {
        // This setup approximates last 4 digits 
        // As the formula is slightly different it produces a minimal discrepancy in the last digit 
        // we make a check on the first 14 digits for 1e18 in a loop with 100 iterations
        uint256 price = 1e18;
        uint256 delta = 100;
        uint256 expectedPrice = price;
        for (int i; i < 100; i++){
            for (int j ; j < i; j++){
                expectedPrice += expectedPrice * delta / 10000;
            }
            assertTrue(pool._calculateOrderPrice(i, price, delta, true) / 1e4 == expectedPrice / 1e4);
            expectedPrice = price;
        }
        for (int i; i < 100; i++){
            for (int j ; j < i; j++){
                expectedPrice -= expectedPrice * delta / 10000;
            }
            assertTrue(pool._calculateOrderPrice(-i, price, delta, true) / 1e4 == expectedPrice / 1e4);
            expectedPrice = price;
        }
    }

    function test_Fuzz_Linear_CalculateOrderPrice(int32 signedCurrentOrder, uint256 price, uint256 delta) public {
        vm.assume(price < 1e28);
        vm.assume(delta < 1e18);
        vm.assume(signedCurrentOrder < 1000 && signedCurrentOrder > 0);
        assertTrue(pool._calculateOrderPrice(signedCurrentOrder, price, delta, false) == price + uint32(signedCurrentOrder) * delta);
    }
    
    function test_CalculateOrderPrice_OverflowScenario() public {
        assertTrue(pool._calculateOrderPrice(1e18, 1e18, 1e6, true) == type(uint256).max);
    }


    function test_exponential_calculateTotalPrice() public {
        uint256 price = 1e28;
        uint256 delta = 100;
        uint256 expectedCumulativePrice;
        int256 signedCurrentOrder = -10;
        for (int i; i<100; ++i){
            expectedCumulativePrice += pool._calculateOrderPrice(signedCurrentOrder, price, delta, true);
            signedCurrentOrder++;
        }
        signedCurrentOrder = -10;
        assertTrue(pool._calculateTotalPrice(signedCurrentOrder, price, 100, delta, true, true) == expectedCumulativePrice);


        delete expectedCumulativePrice;
        for (int i; i<100; ++i){
            expectedCumulativePrice += pool._calculateOrderPrice(signedCurrentOrder, price, delta, true);
            signedCurrentOrder--;
        }
        signedCurrentOrder = -10;
        assertTrue(pool._calculateTotalPrice(signedCurrentOrder, price, 100, delta, true, false) == expectedCumulativePrice);

    }

    function test_linear_calculateTotalPrice() public {
        uint256 price = 1e28;
        uint256 delta = 100;
        uint256 expectedCumulativePrice;
        int256 signedCurrentOrder = -10;
        for (int i; i<100; ++i){
            expectedCumulativePrice += pool._calculateOrderPrice(signedCurrentOrder, price, delta, false);
            signedCurrentOrder++;
        }
        signedCurrentOrder = -10;
        assertTrue(pool._calculateTotalPrice(signedCurrentOrder, price, 100, delta, false, true) == expectedCumulativePrice);


        delete expectedCumulativePrice;
        for (int i; i<100; ++i){
            expectedCumulativePrice += pool._calculateOrderPrice(signedCurrentOrder, price, delta, false);
            signedCurrentOrder--;
        }
        signedCurrentOrder = -10;
        assertTrue(pool._calculateTotalPrice(signedCurrentOrder, price, 100, delta, false, false) == expectedCumulativePrice);

    }
 
    function test_public_calculateTotalPrice() public {
        uint256 delta = 10;
        uint256 price = 1e18;
        uint16 fee = 10;
        uint16 maxBuyOrders = 10;
        pool.mock_signedCurrentOrder(-10);
        pool.setPoolProperties(price, delta, maxBuyOrders, fee, true);
        uint256 expectedCumulativePrice;
        int256 signedCurrentOrder = pool._signedCurrentOrder();
        for (int i; i<10; ++i){
            expectedCumulativePrice += pool._calculateOrderPrice(signedCurrentOrder, price, delta, true);
            signedCurrentOrder++;
        }
        assertTrue(pool.calculateTotalPrice(10, true) == expectedCumulativePrice);
    }


    function test_getBuyPrice_getSellPrice() public {
        uint256 delta = 10;
        uint256 price = 1e18;
        uint16 fee = 10;
        uint16 maxBuyOrders = 10;
        pool.setPoolProperties(price, delta, maxBuyOrders, fee, true);
        pool.mock_signedCurrentOrder(100);

        uint256 priceBeforeFee= pool._calculateOrderPrice(
            pool._signedCurrentOrder(),
            price,
            delta, 
            true
        );

        assertTrue(pool.getBuyPrice() == priceBeforeFee - (priceBeforeFee * fee / 1000));
        assertTrue(pool.getSellPrice() == priceBeforeFee);
    }

    function testSwapFee() public {
        uint256 price = 1e18;
        uint16 fee = 10;
        pool.setPoolProperties(price, 0, 0, fee, true);
        assertTrue(pool.getSwapFee()== (price * fee) / 1000);
    }

    function test_Swap() public {
        col.setApprovalForAll(address(ys), true);
        uint256[] memory tokenArray = new uint256[](1);
        tokenArray[0] = 1;
        pool.deposit(tokenArray);
        
        vm.prank(alan);
        col.setApprovalForAll(address(ys), true);
        vm.prank(alan);
        vm.expectRevert();
        pool.swapNFT(2,1);
        
        vm.prank(alan);
        pool.swapNFT(101,1);
        assertTrue(col.ownerOf(1) == alan);
        assertTrue(col.ownerOf(101) == address(pool));

        pool.setPoolProperties(1e18, 0, 10, 10, true);
        vm.prank(alan);
        vm.expectRevert("Pool: wrong  value");
        pool.swapNFT(1,101);

        uint256 feeCost = pool.getSwapFee();
        vm.prank(alan);
        pool.swapNFT{value: feeCost}(1,101);

        assertTrue(col.ownerOf(101) == alan);
        assertTrue(col.ownerOf(1) == address(pool));
    }

    function test_PoolSell() public {
        set_DepositFUND_DepositNFT_and_SetPoolProperties();
        uint256[] memory tokenArray = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            tokenArray[i] = i + 1;
        }
        pool.mock_set_buyCount(5);
        uint256 cumulativeAmountToPay = pool.calculateTotalPrice(tokenArray.length, false);
        uint256 initialPoolBalance = address(pool).balance;
        vm.prank(alan);

        pool.batchSellNFT{value: cumulativeAmountToPay}(tokenArray);
        assertTrue(address(pool).balance - initialPoolBalance == cumulativeAmountToPay);
        for (uint256 i = 0; i < 10; i++) {
            assertTrue(col.ownerOf(i+1) == alan);
        }

        assertTrue(pool._signedCurrentOrder() == 10);
        assertTrue(pool._buyCount() == 0);
    }

    function test_PoolSell_Requirements() public {
        
        uint256[] memory tokenArray = new uint256[](0);
        uint256 price = 0;
        
        pool.setPoolProperties(price, 0, 0, 0, true);
        vm.prank(alan);
        vm.expectRevert("Not for sale");
        pool.batchSellNFT{value: 0}(tokenArray);
        price = 1e18;
        pool.setPoolProperties(price, 0, 0, 0, true);
        vm.prank(alan);
        vm.expectRevert("No token selected");
        pool.batchSellNFT{value: price}(tokenArray);

        tokenArray = new uint256[](1);
        tokenArray[0] = 1;

        vm.prank(alan);
        vm.expectRevert("Wrong amount");
        pool.batchSellNFT{value: price + 1}(tokenArray);
    }


   
    function test_poolBuy() public {
        
        uint256 price = 1e18;
        uint256 delta = 10; // 10%
        uint16 maxOrderBuy = 10;
        uint16 fee = 10; // 1%
        bool isExponential = true;
        pool.setPoolProperties(price, delta,  maxOrderBuy, fee, isExponential);
        uint256[] memory emptyArr = new uint256[](0);
        uint256[] memory tokenArray = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            tokenArray[i] = i + 100;
        }   
        
        vm.prank(alan);
        col.setApprovalForAll(address(ys), true);

        vm.prank(alan);
        vm.expectRevert("Pool: empty array");
        pool.batchBuyNFT(emptyArr);

        pool.setPoolProperties(price, delta, 9, fee, isExponential);
        vm.prank(alan);
        vm.expectRevert("Pool: buy order limit met");
        pool.batchBuyNFT(tokenArray);

        pool.setPoolProperties(price, delta, 9, fee, isExponential);
        uint256 cumulativePriceAmount = pool.calculateTotalPrice(tokenArray.length, false);
        uint256 amountAfterFeeReduction = cumulativePriceAmount - (cumulativePriceAmount * fee / 1000);
        vm.prank(alan);
        vm.expectRevert();
        pool.batchBuyNFT(tokenArray);
        
        pool.setPoolProperties(price, delta, 10, fee, isExponential);
        vm.prank(alan);
        vm.expectRevert();
        pool.batchBuyNFT(tokenArray);


        pool.deposit{value: 11e18}(new uint256[](0));
        vm.prank(alan);
        pool.batchBuyNFT(tokenArray);
        assertTrue(pool._signedCurrentOrder() == -10);
        assertTrue(pool._buyCount() == 10);
    }

    function test_getBuyOrders() public {
        pool.deposit{value: 10e18}(new uint256[](0));
        uint256 price = 1e18;
        uint256 delta = 0; // 10%
        uint16 maxOrderBuy = 10;
        uint16 fee = 0; // 1%
        bool isExponential = true;
        pool.setPoolProperties(price, delta,  maxOrderBuy, fee, isExponential);
        

        assertTrue(pool.getBuyOrders() == 10);

        pool.mock_set_buyCount(5);
        assertTrue(pool.getBuyOrders() == 5);

        pool.setPoolProperties(price, delta,  2, fee, isExponential);
        assertTrue(pool.getBuyOrders() == 2);

        pool.setPoolProperties(price, delta,  2, fee, isExponential);
        pool.mock_set_buyCount(0);
        assertTrue(pool.getBuyOrders() == 2);

        pool.setPoolProperties(price, delta,  0, fee, isExponential);
        pool.mock_set_buyCount(5);
        assertTrue(pool.getBuyOrders() == 0);

        price = 1e18 + 1e17;
        pool.mock_set_buyCount(0);
        pool.setPoolProperties(price, delta,  10, fee, isExponential);
        assertTrue(pool.getBuyOrders() == 9);



    }


    function set_DepositFUND_DepositNFT_and_SetPoolProperties() internal{
        col.setApprovalForAll(address(ys), true);
        
        uint256[] memory tokenArray = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            tokenArray[i] = i + 1;
        }
        pool.deposit{value: 10e18}(tokenArray);
       
        uint256 price = 1e18;
        uint256 delta = 1e2; // 10%
        uint16 fee = 10; // 1%
        uint16 maxOrderBuy = 10;
        bool isExponential = true;
        pool.setPoolProperties(price, delta,  maxOrderBuy, fee, isExponential);

    }
    
    receive() external payable {
        
    }


    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }





}