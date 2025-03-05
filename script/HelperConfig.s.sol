//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants{
    /*MOCK VALUES*/
    uint96 constant MOCK_BASE_FEE = 0.25 ether;
    uint96 constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants{

    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 enteranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint16 callbackGasLimit;
    }
    
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainid => NetworkConfig) public networkConfigs;
    constructor(){
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaETHConfig();
    }

    function getConfigByChainId(uint256 chainid) public returns(NetworkConfig memory){
        if(networkConfigs[chainid].vrfCoordinator != address(0)){
            return networkConfigs[chainid];
        }else if(chainid == LOCAL_CHAIN_ID){
            return getOrCreateAnvilETHConfig();
        }else{
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaETHConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig({
            enteranceFee : 0.01 ether,
            interval : 30 ,
            vrfCoordinator : 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane : 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit : 50000 
        });
    }

    function getOrCreateAnvilETHConfig() public returns(NetworkConfig memory) {
        if(localNetworkConfig.vrfCoordinator != address(0)){
            return localNetworkConfig;
        }

        //Deploy Mocks
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            enteranceFee : 0.01 ether,
            interval : 30 ,
            vrfCoordinator : address(vrfCoordinatorMock),
            gasLane : 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,    //--> might fix this later
            callbackGasLimit : 50000 
        });
        return localNetworkConfig;
    }
}