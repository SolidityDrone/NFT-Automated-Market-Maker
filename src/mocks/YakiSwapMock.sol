// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract YakiSwapMock is ReentrancyGuard {
    event Pool_Creation(
        address indexed poolAddress,
        address indexed owner,
        address indexed collection,
        uint256 poolID
    );
    event UserBuy(
        address indexed pool,
        address indexed user,
        uint256[] tokenId,
        uint256 price
    );
    event UserSell(
        address indexed pool,
        address indexed user,
        uint256[] tokenId,
        uint256 price
    );
    event Swap(
        address indexed pool,
        address indexed user,
        uint256 tokenIn,
        uint256 tokenOut,
        uint256 price
    );
    event PropertiesEdit(
        address indexed pool,
        uint256 spotPrice,
        uint256 delta,
        uint16 maxBuyOrders,
        uint16 fee, 
        bool isExponential
    );
    event BalanceUpdate(
        address indexed pool
    );
    uint256 public _poolCounter;
    address public immutable _implementationPool;
    mapping(uint256 => address) public s_Pool_Address_By_ID;
    mapping(address => uint256) public s_Pool_ID_By_Address;
    enum EventType {USER_SELL, USER_BUY, USER_SWAP}
   


    constructor() {
        _implementationPool = address(new Pool());
        _poolCounter = 1;
    }

    function createPool(
        address collection,
        uint256 spotPrice,
        uint256 delta,
        uint16 maxBuyOrders,
        uint16 fee, 
        bool isExponential, 
        uint256[] calldata tokenId
        ) public payable{
        address payable cloneAddress = payable(
            Clones.clone(_implementationPool)
        );
        s_Pool_Address_By_ID[_poolCounter] = cloneAddress;
        s_Pool_ID_By_Address[cloneAddress] = _poolCounter;
        Pool(cloneAddress).initialize(msg.sender, collection);
        emit Pool_Creation(cloneAddress, msg.sender, collection, _poolCounter);
        _incrementCounter();
        Pool(cloneAddress).setPoolProperties(spotPrice, delta, maxBuyOrders, fee, isExponential);
        Pool(cloneAddress).deposit{value: msg.value}(tokenId);
    }


    function _incrementCounter() public  {
        unchecked {
            ++_poolCounter;
        }
    }

    function getPoolAddress(uint256 poolID) external view returns (address) {
        return s_Pool_Address_By_ID[poolID];
    }

    function getPoolID(address poolAddress) external view returns (uint256) {
        return s_Pool_ID_By_Address[poolAddress];
    }

    function handleTransfer(
        address collectionAddress,
        address from,
        uint256 tokenId
    ) external virtual returns (bool) {
        require(s_Pool_ID_By_Address[msg.sender] != 0, "Not Allowed");
        IERC721(collectionAddress).safeTransferFrom(
            from,
            msg.sender,
            tokenId,
            ""
        );
        return true;
    }

    function handlePoolEvent(
        address user, 
        uint256 price,
        uint256[] calldata tokenId,
        EventType eventEnum
    ) external virtual {
        require(s_Pool_ID_By_Address[msg.sender] != 0, "Not Allowed");
        if (eventEnum == EventType.USER_BUY){
            emit UserBuy(msg.sender, user, tokenId, price);
        } 
        if (eventEnum == EventType.USER_SELL){
            emit UserSell(msg.sender, user, tokenId, price);
        }
        if (eventEnum == EventType.USER_SWAP){
            emit Swap(msg.sender, user, tokenId[0], tokenId[1], price);
        }
       
    }
    function handlePropertiesEditEvent(
        uint256 spotPrice,
        uint256 delta,
        uint16 maxBuyOrders,
        uint16 fee, 
        bool isExponential
    ) external virtual {
        require(s_Pool_ID_By_Address[msg.sender] != 0, "Not Allowed");
        emit PropertiesEdit(msg.sender, spotPrice, delta, maxBuyOrders, fee, isExponential);
    }
    function handleBalance() external virtual {
        require(s_Pool_ID_By_Address[msg.sender] != 0, "Not Allowed");
        emit BalanceUpdate(msg.sender);
    }
}

contract Pool is IERC721Receiver, ReentrancyGuard {
   

    PoolProperties public properties;
    int256 public _signedCurrentOrder;
    address public _owner;
    IERC721 public _collection;
    YakiSwapMock public _parent;
    uint32 public _buyCount;
    bool public _initialized;

    struct PoolProperties {
        uint256 spotPrice;
        uint256 delta;
        uint16 maxBuyOrders;
        uint16 fee;
        bool isExponential;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Pool: not owner");
        _;
    }

    modifier onlyOwnerOrParent() {
        require(msg.sender == _owner || msg.sender == address(_parent), "Pool: not owner");
        _;
    }

      
    function mock_signedCurrentOrder(int256 n) public {
        _signedCurrentOrder = n;
    }

    function mock_set_buyCount(uint32 n) public {
        _buyCount = n;
    }



    function initialize(address owner, address collection) public {
        require(!_initialized, "Already initialized");
        _owner = owner;
        _collection = IERC721(collection);
        _initialized = true;
        _parent = YakiSwapMock(msg.sender);
    }

    //// OWNER FUNCTION ///
    function setPoolProperties(
        uint256 spotPrice,
        uint256 delta,
        uint16 maxBuyOrders,
        uint16 fee,
        bool isExponential
    ) public onlyOwnerOrParent {
        properties.spotPrice = spotPrice;
        properties.delta = delta;
        properties.fee = fee;
        properties.maxBuyOrders = maxBuyOrders;
        properties.isExponential = isExponential;
        delete _buyCount;
        delete _signedCurrentOrder;
        _parent.handlePropertiesEditEvent(spotPrice, delta, maxBuyOrders, fee, isExponential);
    }


 
    function withdraw(uint256[] calldata tokenId, uint256 amount) public onlyOwner nonReentrant {
        for (uint256 i; i < tokenId.length; ) {
            _collection.safeTransferFrom(address(this), msg.sender, tokenId[i]);
            unchecked {
                ++i;
            }
        }
        if (amount > 0){
            (bool sent, ) = msg.sender.call{value: amount}("");
            require(sent, "Failed to send Ether");
        }
        _parent.handleBalance();
    }

    function deposit(uint256[] calldata tokenId) public payable onlyOwnerOrParent {
        for (uint256 i; i < tokenId.length; ) {
            _parent.handleTransfer(
                address(_collection),
                _owner,
                tokenId[i]
            );
            unchecked {
                ++i;
            }
        }
        _parent.handleBalance();
    }

   

    

    receive() external payable {}

    // USER

    function swapNFT(uint256 tokenIn, uint256 tokenOut) public payable {
        require(msg.value == getSwapFee(), "Pool: wrong  value");
        _collection.safeTransferFrom(address(this), msg.sender, tokenOut, "");
        _parent.handleTransfer(address(_collection), msg.sender, tokenIn);
        uint256[] memory tokens = new uint256[](2);
        _parent.handlePoolEvent(msg.sender, getSwapFee(), tokens, YakiSwapMock.EventType.USER_SWAP);
    }

    function batchSellNFT(
        uint256[] calldata tokenId
    ) public payable nonReentrant {
        require(properties.spotPrice != 0, "Not for sale");
        require(tokenId.length > 0, "No token selected");
        uint256 cumulativePrice = calculateTotalPrice(tokenId.length, false);
        require(msg.value == cumulativePrice, "Wrong amount");
     
        for (uint256 i; i < tokenId.length; ) {
            _collection.safeTransferFrom(
                address(this),
                msg.sender,
                tokenId[i],
                ""
            );
            

            if (_buyCount != 0) {
                _buyCount--;
            }
            unchecked {
                ++_signedCurrentOrder;
                ++i;
            }
        }
        _parent.handlePoolEvent(msg.sender, msg.value, tokenId, YakiSwapMock.EventType.USER_BUY);
        
    }

    function batchBuyNFT(uint256[] calldata tokenId) public nonReentrant {
        require(
            properties.maxBuyOrders >= _buyCount + tokenId.length,
            "Pool: buy order limit met"
        );
        require(tokenId.length > 0, "Pool: empty array");
        uint256 cumulativePrice = calculateTotalPrice(tokenId.length, true);
        require(
            address(this).balance >= cumulativePrice,
            "Pool: not enough funds"
        );
      
        cumulativePrice -= ((cumulativePrice * properties.fee) / 1000);
        for (uint256 i; i < tokenId.length; ) {
            _parent.handleTransfer(
                address(_collection),
                msg.sender,
                tokenId[i]
            );


            unchecked {
                --_signedCurrentOrder;
                ++_buyCount;
                ++i;
            }
        }
        _parent.handlePoolEvent(msg.sender, cumulativePrice, tokenId, YakiSwapMock.EventType.USER_SELL);
       
        (bool sent, ) = msg.sender.call{value: cumulativePrice}("");
        require(sent, "Failed to send Ether");
    }

    // LOGIC FUNCTIONS

    function calculateTotalPrice(
        uint256 iterations,
        bool isSelling
    ) public view returns (uint256) {
        PoolProperties memory props = properties;
        return
            _calculateTotalPrice(
                _signedCurrentOrder,
                props.spotPrice,
                iterations,
                props.delta,
                props.isExponential,
                isSelling
            );
    }

    function getSellPrice() external view returns (uint256) {
        return
            _calculateOrderPrice(
                _signedCurrentOrder,
                properties.spotPrice,
                properties.delta,
                properties.isExponential
            );
    }

    function getBuyPrice() external view returns (uint256) {
        uint256 price = _calculateOrderPrice(
            _signedCurrentOrder,
            properties.spotPrice,
            properties.delta,
            properties.isExponential
        );
        return price - ((price * properties.fee) / 1000);
    }

    function getSwapFee() public view returns (uint256) {
        return (properties.spotPrice * properties.fee) / 1000;
    }

    function _absoluteModule(int256 x) public pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }

    function _calculateOrderPrice(
        int256 signedCurrentOrder,
        uint256 price,
        uint256 delta,
        bool isExponential
    ) public pure returns (uint256) {
        uint256 finalPrice = price;
        uint256 n = _absoluteModule(signedCurrentOrder);
        uint256 factor;

        if (isExponential) {
            if (signedCurrentOrder < 0) {
                factor = 1e18 - (delta * 1e14);
            } else {
                factor = 1e18 + (delta * 1e14);
            }

            while (n > 0) {
                if (n & 1 == 1) {
                    (bool success1, uint256 newPrice) = SafeMath.tryMul(
                        finalPrice,
                        factor
                    );
                    if (!success1) {
                        return type(uint256).max;
                    }
                    finalPrice = newPrice / 1e18;
                }
                (bool success2, uint256 newFactor) = SafeMath.tryMul(
                    factor,
                    factor
                );
                if (!success2) {
                    return type(uint256).max;
                }
                factor = newFactor / 1e18;
                n = n >> 1;
            }
            return finalPrice;
        } else {
            if (signedCurrentOrder < 0) {
                return finalPrice -= n * delta;
            } else {
                return finalPrice += n * delta;
            }
        }
    }

    function _calculateTotalPrice(
        int256 signedCurrentOrder,
        uint256 price,
        uint256 iterations,
        uint256 delta,
        bool isExponential,
        bool isSelling
    ) public pure returns (uint256) {
        uint256 cumulativePrice;

        if (isSelling) {
            for (uint256 i; i < iterations; ) {
                cumulativePrice += _calculateOrderPrice(
                    signedCurrentOrder,
                    price,
                    delta,
                    isExponential
                );
                ++signedCurrentOrder;
                unchecked {
                    ++i;
                }
            }
        } else {
            for (uint256 i; i < iterations; ) {
                cumulativePrice += _calculateOrderPrice(
                    signedCurrentOrder,
                    price,
                    delta,
                    isExponential
                );
                --signedCurrentOrder;
                unchecked {
                    ++i;
                }
            }
        }

        return cumulativePrice;
    }

    function getSellOrders() external view returns (uint) {
        return _collection.balanceOf(address(this));
    }

    function getBuyOrders() external view returns (uint) {
        uint cumulativePrice;
        int signedCurrentOrder = _signedCurrentOrder;
        if (
            properties.maxBuyOrders < _buyCount || properties.maxBuyOrders == 0
        ) {
            return 0;
        }
        uint availableOrders = properties.maxBuyOrders - _buyCount;
        for (uint i; i < availableOrders; ++i) {
            uint nextPrice = _calculateOrderPrice(
                signedCurrentOrder,
                properties.spotPrice,
                properties.delta,
                properties.isExponential
            );
            nextPrice -= (nextPrice * properties.fee) / 1000;
            if (cumulativePrice + nextPrice > address(this).balance) {
                return i;
            }
            cumulativePrice += nextPrice;
            --signedCurrentOrder;
        }
        return availableOrders;
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
