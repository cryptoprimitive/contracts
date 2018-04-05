// TODO:
// The 'burn' parameter on a submitted message should be removed.
// It adds complexity to a system that is already difficult for a new user to understand,
// and doesn't add anything too meaningful, given that a poster can add however much they want as a deposit,
// which serves the purpose of proving their belief in the message's value.

pragma solidity ^0.4.19;

contract BurnChatManager {
    struct ActiveMessage {
        address from;
        uint balance;
        uint burnFactor;//1000 corresponds to a 1:1 ratio; higher requires the burner to burn more of his ether to burn the same amount from the message
        uint finalizeTime;
    }

    address constant burnAddress = 0x0;

    ActiveMessage[] public activeMessages;

    event NewMessage(uint messageID, address from, string message, uint amountBurned, uint amountDeposited, uint finalizeTime, uint burnFactor);
    event MessageBurned(uint messageID, address burner, uint initiatingBurn, uint resultingBurn);
    event MessageTipped(uint messageID, address tipper, uint amount);
    event MessageFinalized(uint messageID, uint amountReturned);
    event MessageSmoked(uint messageID);

    function burn(uint amount)
    internal {
        burnAddress.transfer(amount);
    }

    function post(string message, uint initialBurn, uint finalizeInterval, uint burnFactor)
    external
    payable
    returns (uint) {
        require(msg.value >= initialBurn);
        burn(initialBurn);

        uint amountDeposited = msg.value - initialBurn;

        uint finalizeTime = now + finalizeInterval;

        activeMessages.push(ActiveMessage({from:msg.sender, balance:amountDeposited, burnFactor:burnFactor, finalizeTime:finalizeTime}));
        uint messageID = activeMessages.length - 1;

        NewMessage(messageID, msg.sender, message, initialBurn, amountDeposited, finalizeTime, burnFactor);

        if (amountDeposited == 0) {
            delete activeMessages[messageID];
            MessageSmoked(messageID);
        }

        return messageID;
    }

    function finalizeMessage(uint messageID)
    external {
        require(activeMessages[messageID].from == msg.sender);//This also guarantees activeMessages[messageID] is not null
        require(now >= activeMessages[messageID].finalizeTime);

        uint balance = activeMessages[messageID].balance;

        delete activeMessages[messageID];

        msg.sender.transfer(balance);
        MessageFinalized(messageID, balance);
    }

    function burnMessage(uint messageID)
    external
    payable {
        require(activeMessages[messageID].from != 0x0);//Require the message exists

        uint initiatingBurn = msg.value;

        uint attemptedBurn;
        if (activeMessages[messageID].burnFactor == 0) {
            attemptedBurn = activeMessages[messageID].balance;
        }
        else {
            attemptedBurn = (msg.value*1000)/activeMessages[messageID].burnFactor;
        }

        uint resultingBurn;

        if (attemptedBurn >= activeMessages[messageID].balance) {
            resultingBurn = activeMessages[messageID].balance;

            delete activeMessages[messageID];

            MessageBurned(messageID, msg.sender, initiatingBurn, resultingBurn);
            MessageSmoked(messageID);
        }
        else {
            resultingBurn = attemptedBurn;

            activeMessages[messageID].balance -= resultingBurn;

            MessageBurned(messageID, msg.sender, initiatingBurn, resultingBurn);
        }

        burn(initiatingBurn + resultingBurn);
    }

    function tipMessage(uint messageID)
    external
    payable {
        require(activeMessages[messageID].from != 0x0);

        activeMessages[messageID].balance += msg.value;

        MessageTipped(messageID, msg.sender, msg.value);
    }
}
