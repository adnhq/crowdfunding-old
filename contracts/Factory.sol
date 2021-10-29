// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;
import "./Crowdsale.sol";
import "./TokenContract.sol";

contract Factory{
    address[] public deployedSales;
    mapping(address=>address) saleToToken;

    function createSale(string memory _title, string memory _description, uint _target, uint _minimum, string memory _tokenName, 
    string memory _tokenSymbol, uint _tokenAmount) external {
        TokenContract token = new TokenContract(_tokenName, _tokenSymbol, _tokenAmount);
        address newCrowdSale = address(new Crowdsale(_title, _description, _target, _minimum, msg.sender, token));
        token.approve(newCrowdSale, _tokenAmount);
        saleToToken[newCrowdSale] = address(token);
        deployedSales.push(newCrowdSale);
    }
    function getDeployedSales() external view returns (address[] memory){
        return deployedSales;
    }
    function getTokenAddress(address _crowdsale) external view returns (address){
        return saleToToken[_crowdsale];
    } 
}