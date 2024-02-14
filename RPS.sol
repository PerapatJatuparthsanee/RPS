// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "./CommitReveal.sol";

contract RockPaperScissors is CommitReveal {
    struct Player {
        uint chosenOption; // 0 - Rock, 1 - Fire , 2 - Scissors, 3 - Sponge , 4 - Paper , 5 - Air , 6 - Water , 7 - undefined 
        address playerAddress;
        uint timestamp;
        bool hasInput;
    }
    uint public playerCount = 0;
    uint public totalReward = 0;
    uint public gameTimeout = 20 minutes;
    uint public revealedCount = 0;
    uint public inputCount = 0;

    mapping (uint => Player) public players;
    mapping (address => uint) public playerNumber;

    function joinGame() public payable {
        require(playerCount < 2);
        require(msg.value == 1 ether, "Please input 1 ETH");
        totalReward += msg.value;
        players[playerCount].playerAddress = msg.sender;
        players[playerCount].chosenOption = 7;
        players[playerCount].timestamp = block.timestamp;
        players[playerCount].hasInput = false;
        playerNumber[msg.sender] = playerCount;
        playerCount++;
    }

    function submitOption(uint option) public {
        uint idx = playerNumber[msg.sender];
        require(playerCount == 2);
        require(msg.sender == players[idx].playerAddress);
        require(option >= 0 && option < 7);
        require(revealedCount == 0);

        if (!players[idx].hasInput) {
            players[idx].timestamp = block.timestamp;
            players[idx].hasInput = true;
            inputCount++;
        }

        bytes32 hashedOption = getHash(bytes32(option));
        commit(hashedOption);
    }

    function revealOption(uint option) public {
        require(inputCount == 2);
        reveal(bytes32(option));
        uint idx = playerNumber[msg.sender];
        players[idx].chosenOption = option; 
        revealedCount++;

        if (revealedCount == 2) {
            determineWinnerAndPay();
        }
    }

    function determineWinnerAndPay() private {
        uint player0Option = players[0].chosenOption;
        uint player1Option = players[1].chosenOption;
        address payable account0 = payable(players[0].playerAddress);
        address payable account1 = payable(players[1].playerAddress);

        if (player0Option ==  player1Option) {
            // To pay both players
            account0.transfer(totalReward / 2);
            account1.transfer(totalReward / 2);
        } else if ((player0Option + 3) % 7 < player1Option || player1Option > player0Option) {
            // To pay player1
            account1.transfer(totalReward);
        } else {
            // To pay player0
            account0.transfer(totalReward);
        }

        restartGame();
    }

    function withdraw() public {
        require(playerCount == 1 || playerCount == 2);
        require(msg.sender == players[0].playerAddress || msg.sender == players[1].playerAddress);
        uint idx = playerNumber[msg.sender];

        if (playerCount == 1) {
            idx = 0;
        } else if (playerCount == 2 && inputCount < 2) {
            require(players[idx].hasInput == true);
        } else if (playerCount == 2 && inputCount == 2 && revealedCount < 2) {
            require(commits[msg.sender].revealed == true);
        }

        require(msg.sender == players[idx].playerAddress);
        require(block.timestamp - players[idx].timestamp > gameTimeout);
        address payable  account = payable(players[idx].playerAddress);
        account.transfer(totalReward);

        restartGame();
    }

    function restartGame() private  {
        playerCount = 0;
        totalReward = 0;
        revealedCount = 0;
        inputCount = 0;

        address account0 = players[0].playerAddress;
        address account1 = players[1].playerAddress;

        delete playerNumber[account0];
        delete playerNumber[account1];
        delete players[0];
        delete players[1];
    }
}
