// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PriceConverter} from "./PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

error FundMe_NotOwner();

contract FundMe{
    using PriceConverter for uint256;

    uint256 public constant MINIMUM_USD = 5 * 1e18;

    address[] private s_funders;
    mapping(address funder => uint256 amountFunded) private s_addressToAmountFunded;

    address private immutable i_owner;
    AggregatorV3Interface private s_priceFeed;

    constructor(address priceFeed){
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function fund() public payable {
        require(msg.value.getConvertedRate(s_priceFeed) >= MINIMUM_USD, "didn't send enough ETH");
        s_funders.push(msg.sender);
        s_addressToAmountFunded[msg.sender] += msg.value;
    }

    function cheaperWithdraw() public{
      uint256 fundersLength = s_funders.length;
      for(uint256 funderIndex = 0; funderIndex < fundersLength; funderIndex++){
          address funder = s_funders[funderIndex];
          s_addressToAmountFunded[funder] = 0;
      }
      s_funders = new address[](0);
      (bool callSuccess, ) = payable(msg.sender).call{value: address(this).balance}("");
      require(callSuccess, "Call Failed");
    } 

    function withdraw() public onlyOwner{
        // for(starting index, ending index, step amount)
        for(uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++){
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        // reset the array
        s_funders = new address[](0);

        // actually withdraw funds

        /*
        // transfer
        payable(msg.sender).transfer(address(this).balance);
        // send
        bool sendSuccess = payable(msg.sender).send(address(this).balance);
        require(sendSuccess, "Send Failed");
        */
        // call
        (bool callSuccess, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call Failed");
    }

    function getVersion() public view returns(uint256){
      return s_priceFeed.version();
    }

    modifier onlyOwner() {
        //require(msg.sender == i_owner, "Sender is not Owner!");
        if(msg.sender != i_owner) { revert FundMe_NotOwner();}
        _;
    }

    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }    

    function getAddressToAmountFunded(address fundingAddress) external view returns(uint256){
      return s_addressToAmountFunded[fundingAddress];
    }

    function getFunder(uint256 index) external view returns(address){
      return s_funders[index];
    }

    function getOwner() external view returns(address){
      return i_owner;
    }
}