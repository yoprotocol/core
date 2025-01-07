// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Base_Test } from "../Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";

contract AuthorizeOperatorTest is Base_Test {
    address public controller;
    address public operator;
    bytes32 public nonce;
    uint256 public deadline;

    function setUp() public override {
        Base_Test.setUp();

        // Set up nonce and deadline
        nonce = keccak256(abi.encodePacked("test-nonce"));
        deadline = block.timestamp + 1 hours;
        controller = users.alice;
        operator = users.bob;
    }

    function test_AuthorizeOperator_success() public {
        authorizeOperator(users.aliceKey, controller, operator, true, nonce, deadline, 0);
        assertTrue(depositVault.isOperator(controller, operator));
    }

    function test_AuthorizeOperator_fails_for_invalid_deadline() public {
        uint256 invalidDeadline = block.timestamp - 1;
        authorizeOperator(
            users.aliceKey, controller, operator, true, nonce, invalidDeadline, Errors.SignatureExpired.selector
        );
    }

    function test_AuthorizeOperator_fails_for_invalid_signature() public {
        authorizeOperator(users.bobKey, controller, operator, true, nonce, deadline, Errors.InvalidSignature.selector);
    }

    function test_AuthorizeOperator_fails_for_invalid_operator() public {
        authorizeOperator(
            users.aliceKey, controller, controller, true, nonce, deadline, Errors.CannotSetSelfAsOperator.selector
        );
    }

    function test_AuthorizeOperator_fails_for_invalid_nonce() public {
        authorizeOperator(users.aliceKey, controller, operator, true, nonce, deadline, 0);
        assertTrue(depositVault.isOperator(controller, operator));
        // solhint-disable-next-line max-line-length
        authorizeOperator(users.aliceKey, controller, operator, true, nonce, deadline, Errors.NonceAlreadyUsed.selector);
    }
}
