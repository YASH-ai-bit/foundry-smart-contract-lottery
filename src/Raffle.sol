//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    //ERRRORS
    error Raffle__NotSentEnough();
    error Raffle__NotEnoughTimeHasPassed();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance,  uint256 number_of_players, uint256 state);

    //TYPE DECLARATIONS
    enum RaffleState {
        OPEN, //0
        CALCULATING //1

    }

    //VARIABLES
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUMWORDS = 1;
    uint256 private immutable i_enteranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint16 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address payable s_recentWinner;
    RaffleState private s_raffleState;

    //EVENTS
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 enteranceFee,
        uint256 interval,
        address _vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint16 callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_enteranceFee = enteranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_enteranceFee) {
            revert Raffle__NotSentEnough();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev - This is the function the chainlink nodes will call when it is ready to pick a winner. 
     * The following should be ttrue in order to pick a winner:
     * 1. The time interval has passed.
     * 2. The lottery is open.
     * 3. Your subscriptionId has LINK.
     * 4. The contract has ETH.
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart the lottery
     * @return -ignored
     */

    function checkUpkeep(bytes memory /*checkdata*/)
        public
        view
        returns (bool upkeepNeeded, bytes memory /*perform data*/ )
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasETH = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasETH && hasPlayers ;
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep( bytes calldata /*perform Data*/) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if(!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded( address(this).balance , s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUMWORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        s_vrfCoordinator.requestRandomWords(request);
        
    }

    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    //GETTER FUNCTIONS
    function getEnteranceFee() external view returns (uint256) {
        return i_enteranceFee;
    }
}
