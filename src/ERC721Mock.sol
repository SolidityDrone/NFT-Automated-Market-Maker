// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Mock is ERC721 {
    uint internal counter;
    constructor()   ERC721("",""){
       
    }

    function mint() public {
        _safeMint(msg.sender, counter);
        counter++;
    }
    
}