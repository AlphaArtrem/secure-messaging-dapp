// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SecureMessaging {
    string public constant name = "SecureMessaging";
    string public constant version = "1.0";

    struct ConversationNode {
        bytes32 conversationId;
        uint256 latestTimestamp;
        bytes32 prevConversationId;
        bytes32 nextConversationId;
    }

    struct Message {
        bytes32 encryptedMessageIpfsHash; //The encryptedMessageIpfsHash will resolve to a JSON file which will contain the sender, receiver, message contents etc.
        bytes32 encryptedDecryptionKeyForSender; //Decryption key for encrypted JSON file stored on IPFS, encrypted using sender's public key
        bytes32 encryptedDecryptionKeyForReceiver; //Decryption key for encrypted JSON file stored on IPFS, encrypted using receiver's public key
    }

    mapping(address user => bytes32 lastestConversationId) private userHeads;
    mapping(address user => mapping(bytes32 conversationId => ConversationNode conversation) conversationNodesOfAnUser)
        private conversationNodes;
    mapping(bytes32 conversationId => Message[] Message)
        private conversationMessages;

    event MessageSent(
        bytes32 indexed conversationId,
        address indexed sender,
        address indexed receiver,
        bytes32 encryptedMessageIpfsHash
    );

    event ConversationCreated(
        bytes32 indexed conversationId,
        address indexed sender,
        address indexed receiver
    );

    event ConversationUpdated(
        bytes32 indexed conversationId,
        address indexed sender,
        address indexed receiver
    );

    function sendMessage(
        address receiver,
        bytes32 encryptedMessageIpfsHash,
        bytes32 encryptedDecryptionKeyForSender,
        bytes32 encryptedDecryptionKeyForReceiver
    ) public {
        //Generate conversationId
        bytes32 conversationId = keccak256(
            abi.encodePacked(msg.sender, receiver)
        );

        //Push IPFS hash of message to the conversation
        conversationMessages[conversationId].push(
            Message({
                encryptedMessageIpfsHash: encryptedMessageIpfsHash,
                encryptedDecryptionKeyForSender: encryptedDecryptionKeyForSender,
                encryptedDecryptionKeyForReceiver: encryptedDecryptionKeyForReceiver
            })
        );

        //If this conversationId's conversationNode does't exist create and insert a new conversation node for both sender and receiver
        if (conversationNodes[msg.sender][conversationId].conversationId == 0) {
            ConversationNode memory newNode = ConversationNode({
                conversationId: conversationId,
                latestTimestamp: block.timestamp,
                prevConversationId: userHeads[msg.sender],
                nextConversationId: 0
            });

            //Add conversationNode for sender
            _addConversationNode(newNode, msg.sender);

            //Add conversationNode for receiver
            newNode.prevConversationId = userHeads[receiver];
            _addConversationNode(newNode, receiver);

            emit ConversationCreated(conversationId, msg.sender, receiver);
        } else {
            _updateConversationNode(conversationId, msg.sender);
            _updateConversationNode(conversationId, receiver);
            emit ConversationUpdated(conversationId, msg.sender, receiver);
        }

        emit MessageSent(
            conversationId,
            msg.sender,
            receiver,
            encryptedMessageIpfsHash
        );
    }

    function _addConversationNode(
        ConversationNode memory newNode,
        address user
    ) private {
        //If this not the first conversation for the user than make it the next conversation for the current head conversationNode
        if (userHeads[user] != 0) {
            conversationNodes[user][userHeads[user]]
                .nextConversationId = newNode.conversationId;
        }
        //Add the conversationNode to the double linked list of conversationNodes
        conversationNodes[user][newNode.conversationId] = newNode;
        //Make this conversationNode the new head
        userHeads[user] = newNode.conversationId;
    }

    function _updateConversationNode(
        bytes32 conversationId,
        address user
    ) private {
        //If this conversationId's conversationNode exists update it's latestTimestamp
        conversationNodes[user][conversationId].latestTimestamp = block
            .timestamp;
        //If this conversationId's conversationNode is not the latest conversation make it the head for both sender and receiver
        if (userHeads[user] != conversationId) {
            //Remove this conversationId from the doble linnked list so the it's adjacent nodes on both side are lined to each other
            conversationNodes[user][
                conversationNodes[user][conversationId].prevConversationId
            ].nextConversationId = conversationNodes[user][conversationId]
                .nextConversationId;
            conversationNodes[user][
                conversationNodes[user][conversationId].nextConversationId
            ].prevConversationId = conversationNodes[user][conversationId]
                .prevConversationId;

            //Make this conversationId's conversationNode as latest conversation
            conversationNodes[user][userHeads[user]]
                .nextConversationId = conversationId;
            conversationNodes[user][conversationId]
                .prevConversationId = userHeads[user];
            conversationNodes[user][conversationId].nextConversationId = 0;

            //Make this conversationId's conversationNode the current head
            userHeads[user] = conversationId;
        }
    }

    function listConversations(
        bytes32 startNodeConversationId,
        uint256 noOfConversations
    ) public view returns (ConversationNode[] memory) {
        //If startNodeConversationId is not provided start with head
        bytes32 currentConversationId = startNodeConversationId == 0
            ? userHeads[msg.sender]
            : startNodeConversationId;
        uint256 count = 0;
        ConversationNode[] memory conversations = new ConversationNode[](
            noOfConversations
        );
        // Collect conversations from the startNodeConversationId
        while (currentConversationId != 0 && count < noOfConversations) {
            conversations[count] = conversationNodes[msg.sender][
                currentConversationId
            ];
            currentConversationId = conversations[count].prevConversationId;
            count++;
        }
        return conversations;
    }

    function listMessages(
        bytes32 conversationId,
        uint256 startIndex,
        uint256 noOfMessages
    ) public view returns (Message[] memory) {
        //If start index is zero start from the very recent message
        if (
            startIndex == 0 ||
            startIndex >= conversationMessages[conversationId].length
        ) {
            startIndex = conversationMessages[conversationId].length - 1;
        }

        Message[] memory messages = new Message[](noOfMessages);

        //Get messages in descending order
        for (uint256 i = 0; i < noOfMessages && startIndex - i > 0; i++) {
            messages[i] = conversationMessages[conversationId][startIndex - i];
        }
        return messages;
    }
}
