//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenContract is ERC20{
 
    constructor(string memory _name, string memory _symbol, uint _amount) ERC20(_name, _symbol){
        _mint(msg.sender, _amount);
        
    }
    function decimals() public pure override returns (uint8) {
        return 0;
    }
    
    function burn(address _account, uint _amount) public {
        _burn(_account , _amount);
    }
    
}