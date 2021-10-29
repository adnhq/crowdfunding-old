// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;
import "./TokenContract.sol";

contract Crowdsale{
    uint8 reqCounter;
    uint16 public endVotes;
    uint32 public contributors;
    bool requestEnd;
    uint public raisedAmount;
    uint public startingTime;
    uint public endingTime;
    uint public targetAmount;
    uint public minimumContribution;
    string public title; 
    string public description; 
    
    mapping(address=>uint) contributedAmount;
    struct Request{
        string description;
        uint amount;
        address payable recipient;
        mapping(address => bool) votes;
        uint16 voteCount;
        bool completed;
    }
    
    TokenContract token;
    address public owner;
    address factory;
    address tokenAddress;
    mapping(uint => Request) requests;
    enum State {RUNNING, PAUSED, ENDED}
    State currentState;

    event Contribution(address _from, uint _amount);
    event RequestMade(string _description, uint _amount, address payable _recipient);
    event Payment(uint index, address payable _recipient, uint _amount);
    event EndRequest(uint _time, string _reason);
    event Ended(uint _contributors, uint _raisedAmount, uint _endTime);

    constructor(string memory _title, string memory _description, uint _targetAmount, uint _minimumContribution, address _owner, TokenContract _token){
        owner = _owner;
        startingTime = block.timestamp;
        endingTime = startingTime + 4 weeks;
        targetAmount = _targetAmount;
        minimumContribution = _minimumContribution;
        title = _title;
        description = _description;
        token = _token;
        tokenAddress = address(token);
        factory = msg.sender;
        currentState = State.RUNNING;
    }
    
    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }
    modifier goalMet{
        require(raisedAmount>targetAmount);
        _;
    }
    modifier timeMet{
        require(block.timestamp>endingTime);
        _;
    }
    modifier isContributor{
        require(contributedAmount[msg.sender]>0);
        _;
    }
    modifier tokenHolder{
        require(token.balanceOf(msg.sender)>0);
        _;
    }
    modifier saleActive{
        require(currentState == State.RUNNING);
        _;
    }
    modifier saleEnd{
        require(currentState == State.ENDED);
        _;
    }
    receive() external payable{
        contribute();
    }

    function contribute() public payable saleActive{
        require(msg.sender != owner && msg.value>=minimumContribution, "Amount must be higher");
        require(msg.value % minimumContribution == 0, "Value must be a multiple of minimum amount");
        if(contributedAmount[msg.sender] == 0){
            contributors++;
        }
        contributedAmount[msg.sender] += msg.value;
        raisedAmount += msg.value;
        if(token.balanceOf(factory)>=msg.value/minimumContribution){
            token.transferFrom(factory, msg.sender, msg.value/minimumContribution);
        }else if(token.balanceOf(factory)<msg.value/minimumContribution && token.balanceOf(factory)>0){
            token.transferFrom(factory, msg.sender, token.balanceOf(factory));
        }
        emit Contribution(msg.sender, msg.value);
    }
    
    function getTokenBalance() external view returns (uint){
        return token.balanceOf(msg.sender);
    }

    function getRefund() external isContributor tokenHolder timeMet {
        require(raisedAmount<targetAmount, "Target amount has been met");
        payable(msg.sender).transfer(contributedAmount[msg.sender]);
        contributedAmount[msg.sender] = 0;
    }

    function makeRequest(string memory _description, uint _amount, address payable _recipient) external onlyOwner goalMet timeMet saleActive{
        Request storage newRequest = requests[reqCounter];
        newRequest.description = _description;
        newRequest.amount = _amount;
        newRequest.recipient = _recipient;
        reqCounter++;
        emit RequestMade(_description, _amount, _recipient);
    }

    function vote(uint _index) external tokenHolder saleActive{
        Request storage approveRequest = requests[_index];
        require(approveRequest.votes[msg.sender] == false);
        approveRequest.voteCount++;
        approveRequest.votes[msg.sender] = true;
    }
    
    function tokensAvailable() external view returns (uint){
        return token.balanceOf(factory);
    }
    
    function makePayment(uint _index) external onlyOwner saleActive{
        Request storage approveRequest = requests[_index];
        require(approveRequest.completed == false);
        require(approveRequest.voteCount >= contributors/2);
        approveRequest.recipient.transfer(approveRequest.amount);
        approveRequest.completed = true;
        emit Payment(_index, approveRequest.recipient, approveRequest.amount);
    } 

    function _withdrawRemainingTokens() private onlyOwner saleEnd{
        token.transferFrom(factory, owner, token.balanceOf(factory));
    }

    function pause() external onlyOwner saleActive{
        currentState = State.PAUSED;
    }

    function resume() external onlyOwner{
        require(currentState == State.PAUSED);
        currentState = State.RUNNING;
    }

    function endVote() external tokenHolder {
        require(requestEnd, "Voting for sale end has not started yet");
        endVotes++;
    }

    function endRequest(string memory _reason) external onlyOwner timeMet saleActive{
        requestEnd = true;
        emit EndRequest(block.timestamp, _reason);
    }

    function end() external onlyOwner {
        require(currentState != State.ENDED);
        require(endVotes > (contributors/2));
        payable(owner).transfer(address(this).balance);
        currentState = State.ENDED;
        _withdrawRemainingTokens();
        emit Ended(contributors, raisedAmount, block.timestamp);
    }
}