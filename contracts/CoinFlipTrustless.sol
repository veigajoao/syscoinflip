// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CoinFlip is Ownable {

    address public tokenAddress;
    address public walletAddress;
    uint256 public maxBet;
    uint256 public minBet;
    uint256 public betFee;
    uint256 public constant FRACTION_BASE = 100000; 

    struct Game {
        uint256 betSize;
        uint256 settlementBlockNumber;
    }

    mapping(address => Game) public pendingGames;

    constructor(
        address _tokenAddress,
        address _walletAddress,
        uint256 _maxBet,
        uint256 _minBet,
        uint256 _betFee
    ) {
        tokenAddress = _tokenAddress;
        walletAddress = _walletAddress;
        maxBet = _maxBet;
        minBet = _minBet;
        betFee = _betFee;
    }


    function isStarted(address _user) internal view returns (bool) {
        return pendingGames[_user].settlementBlockNumber == 0;
    }


    // implemented as virtual so that contract can b inherited and
    // built to support native ether
    function tokenTransfer(
        address _sender, 
        address _recipient, 
        uint256 _amount
    ) internal virtual {
        IERC20(tokenAddress).transferFrom(_sender, _recipient, _amount);
    }

    function startGame(uint256 _betSize) public payable {
        address user = msg.sender;
        require(_betSize >= minBet && _betSize <= maxBet, "bet outside of min/max range");
        require(!isStarted(user), "user has pending game");
        tokenTransfer(user, walletAddress, _betSize);
        pendingGames[user] = Game({
            betSize: (_betSize * (FRACTION_BASE - betFee)) / FRACTION_BASE,
            settlementBlockNumber: block.number + 3
        });
    }

    function evaluateGame() public {
        address user = msg.sender;
        require(isStarted(user), "user needs to start game before evaluating");
        Game memory userGame = pendingGames[user];
        require(block.number > userGame.settlementBlockNumber, "Need to await settlement block for this game");
        uint256 result = uint256(blockhash(userGame.settlementBlockNumber));
        delete pendingGames[user];
        // in case user takes more than 256 blocks to evaluate answer, hash will
        // equal zero and player will lose their bet
        if (result % 2 == 1) {
            tokenTransfer(walletAddress, user, userGame.betSize * 2);
        }
    }
   
}