//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {console} from "../../lib/forge-std/src/console.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";


contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 enteranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint16 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        enteranceFee = config.enteranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE); //give the player some money
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    modifier playerHasEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    //////////////////ENTER RAFFLE///////////////////

    function testRevertsWhenYouDoNotPayEnough() public {
        //Arrange
        vm.prank(PLAYER);
        //Act and Assert
        vm.expectRevert(Raffle.Raffle__NotSentEnough.selector);
        raffle.enterRaffle();
    }

    function testRaffleUpdatesAfterSomeoneEnters() public playerHasEntered {
        //Arrange
        //modifier used
        //Act
        address playerEntered = raffle.getPlayers(0);
        //Assert
        assert(playerEntered == PLAYER);
    }

    function testEnteringRaffleEmitsEvents() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle)); //don't use modifier as logs are important
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
    }

    function testDontAllowPlayersToEnterWhileItIsCalculating() public playerHasEntered {
        //Arrange
        //modifier used for 1 player enterance and then try to enter another one
        //Act
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        //Assert
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        raffle.enterRaffle{value: enteranceFee}();
    }

    function testCheckupkeepReturnFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenRaffleStateIsNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckupkeepReturnFalseIfEnoughTimeHasPassed() public {
        vm.prank(PLAYER);
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: enteranceFee}();

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    ///////////////////////PERFORM UPKEEP//////////////////////////

    function testPerformUpkeepRevertsFalseIfCheckUpkeepIsFalse() public {
        uint256 balance = 0;
        uint256 number_of_players = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        balance = balance + enteranceFee;
        number_of_players = 1;

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, balance, number_of_players, rState)
        );
        raffle.performUpkeep("");
    }

    //WHAT IF WE NEED TO GET DATA FROM OUR EMITTED EVENTS INTO OUR TESTS:
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public playerHasEntered{
        //Arrange
          //used modifier

        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // console.log("Your requesId is :", requestId);
        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    //////////////////////////FULLFILL RANDOM WORDS//////////////////////////
    function testFullFillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() public playerHasEntered{
        //Act
            //used modifier
        //Arrange //Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(0, address(raffle));
    }
}
