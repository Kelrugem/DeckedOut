GM_HAND_PATH = "gmhand";
PLAYER_HAND_PATH = "cards";

OOB_MSGTYPE_DROPCARD = "dropcard";
OOB_MSGTYPE_DISCARD = "discard"

function onInit()
	OOBManager.registerOOBMsgHandler(CardManager.OOB_MSGTYPE_DROPCARD, handleCardDrop);
	OOBManager.registerOOBMsgHandler(CardManager.OOB_MSGTYPE_DISCARD, handleDiscard);
end

------------------------------------------
-- COMMON FUNCTIONS
------------------------------------------
-- Moves a card from one place to another. 
-- vCard is the card to move.
-- vDestination is the node to move it to
function moveCard(vCard, vDestination, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	vDestination = DeckedOutUtilities.validateNode(vDestination, "vDestination");
	if not vDestination then return end

	local sOldCardNode = vCard.getNodeName();
	local newNode = DB.createChild(vDestination);
	DB.copyNode(vCard, newNode);
	vCard.delete();

	tEventTrace = DeckedOutEvents.raiseOnCardMovedEvent(newNode.getNodeName(), sOldCardNode, tEventTrace);

	return newNode;
end

-- Adds a given card to someone's hand
-- vCard is the card to move
-- sIdentity is either user identity (character sheet node name) or "gm"
function addCardToHand(vCard, sIdentity, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end;
	local handNode = DeckedOutUtilities.validateHandNode(sIdentity);
	if not handNode then return end

	tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_ADDED_TO_HAND);
	local card = CardManager.moveCard(vCard, handNode, tEventTrace);
	DeckedOutEvents.raiseOnCardAddedToHandEvent(card.getNodeName(), sIdentity, tEventTrace);
	
	return card;
end

-- Discards the given card from wherever it is located.
-- The actual discarding has to be done on the host since clients don't have access to the deckbox (where the discard pile is)
-- sIdentity is optional, and should only be present if a player is discarding a card, because the GM has to do the actual disarding, this param is how custody is preserved
function discardCard(vCard, bFacedown, sIdentity, tEventTrace)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	-- If a client is here, we need an OOB.
	if not Session.IsHost then
		sendDiscardMsg(vCard, bFacedown, User.getCurrentIdentity(), tEventTrace);
		return;
	end

	local vDeck = DeckedOutUtilities.validateDeck(CardManager.getDeckIdFromCard(vCard));
	if not vDeck then return end

	-- If for some reason identity is nil, set to GM, since only the GM can get to this point in the functions
	if (sIdentity or "") == "" then
		sIdentity = "gm";
	end

	tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_DISCARDED);
	local card = CardManager.moveCard(vCard, DeckManager.getDiscardNode(vDeck), tEventTrace);
	DeckedOutEvents.raiseOnDiscardFromHandEvent(card.getNodeName(), sIdentity, bFacedown, tEventTrace);
end

-- Given an identity (either a user identity or 'gm'), this discards that users entire hand
function discardHand(sIdentity, tEventTrace)
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	tEventTrace = DeckedOutEvents.raiseOnHandDiscardedEvent(sIdentity, "", tEventTrace);

	for k,card in pairs(CardManager.getHandNode(sIdentity).getChildren()) do
		CardManager.discardCard(card, true, sIdentity, tEventTrace);
	end
end

function discardCardsInHandFromDeck(vDeck, sIdentity)
	if not DeckedOutUtilities.validateHost() then return end
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	local sDeckId = DeckManager.getDeckId(vDeck);
	tEventTrace = DeckedOutEvents.raiseOnHandDiscardedEvent(sIdentity, sDeckId, tEventTrace);

	for k,card in pairs(CardManager.getHandNode(sIdentity).getChildren()) do
		if CardManager.getDeckIdFromCard(card) == sDeckId then
			CardManager.discardCard(card, false, tEventTrace);
		end
	end
end

function putHandBackIntoDeck(sIdentity, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end
	if not DeckedOutItilities.validateIdentity(sIdentity) then return end

	tEventTrace = DeckedOutEvents.raiseOnHandReturnedToDeckEvent(sIdentity, "", tEventTrace)

	for k,card in pairs(CardManager.getHandNode(sIdentity).getChildren()) do
		local vDeck = DeckedOutUtilities.validateDeck(CardManager.getDeckIdFromCard(card));
		if vDeck then
			CardManager.moveCard(card, DeckManager.getCardsNode(vDeck), tEventTrace)
		end
	end
end

function putCardsFromDeckInHandBackIntoDeck(vDeck, sIdentity, tEventTrace) 
	if not DeckedOutUtilities.validateHost() then return end
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	local sDeckId = DeckManager.getDeckId(vDeck);
	tEventTrace = DeckedOutEvents.raiseOnHandReturnedToDeckEvent(sIdentity, sDeckId, tEventTrace)

	for k,card in pairs(CardManager.getHandNode(sIdentity).getChildren()) do
		local deckid = CardManager.getDeckIdFromCard(card);
		local deckNode = DB.findNode(deckid)
		if deckNode and deckid == sDeckId then
			CardManager.moveCard(card, DeckManager.getCardsNode(deckNode), tEventTrace)
		end
	end
end

------------------------------------------
-- HAND FUNCTIONS
------------------------------------------
function getHandNode(sIdentity)
	return DB.createNode(CardManager.getHandPath(sIdentity));
end

function getHandPath(sIdentity)
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	if sIdentity == "gm" then
		return CardManager.GM_HAND_PATH;
	else
		return DB.getPath("charsheet", sIdentity, CardManager.PLAYER_HAND_PATH);
	end
end

function getCardsInHand(sIdentity)
	local handNode = CardManager.getHandNode(sIdentity);
	return DB.getChildren(handNode);
end

function getNumberOfCardsInHand(sIdentity)
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end
	return CardManager.getHandNode(sIdentity).getChildCount();
end

function getNumberOfCardsFromDeckInHand(vDeck, sIdentity)
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	local nCount = 0;
	local sDeckId = DeckManager.getDeckId(vDeck);
	for k,card in pairs(CardManager.getHandNode(sIdentity).getChildren()) do
		local deckid = CardManager.getDeckIdFromCard(card);
		local deckNode = DB.findNode(deckid)
		if deckNode and deckid == sDeckId then
			nCount = nCount + 1;
		end
	end

	return nCount;
end

------------------------------------------
-- DISCARD
------------------------------------------

function sendDiscardMsg(vCard, bFacedown, sIdentity, tEventTrace)
	local msg = {};
	msg.type = CardManager.OOB_MSGTYPE_DISCARD;
	msg.sCardRecord = vCard.getNodeName();
	msg.sSender = sIdentity;

	if tEventTrace and #tEventTrace > 0 then
		for k,v in ipairs(tEventTrace or {}) do
			msg["trace_" .. k] = v;
		end
	end

	Comm.deliverOOBMessage(msg, "");
end

function handleDiscard(msgOOB)
	-- Only the GM should handle this
	if not Session.IsHost then
		return;	
	end

	local tEventTrace = {};
	local i = 1;
	local key = "trace_" .. i;
	local value = msgOOB[key];
	while value ~= nil do
		tEventTrace[i] = value;
		i = i + 1;
		key = "trace_" .. i;
		value = msgOOB[key];
	end

	CardManager.discardCard(msgOOB.sCardRecord, msgOOB.bFacedown == "true", msgOOB.sSender, tEventTrace);
end

------------------------------------------
-- CARD STATES
------------------------------------------
function isCardInDeck(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local sNodeParentName = vCard.getChild("..").getName();
	return StringManager.startsWith(vCard.getNodeName(), "deckbox") and sNodeParentName == DeckManager.DECK_CARDS_PATH;
end

function isCardDiscarded(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local sNodeParentName = vCard.getChild("..").getName();
	return StringManager.startsWith(vCard.getNodeName(), "deckbox") and sNodeParentName == DeckManager.DECK_DISCARD_PATH;
end

function isCardInHand(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return CardManager.isCardOwnedByCharacter(vCard) or CardManager.isCardOwnedByGm(vCard);
end

function isCardOwnedByCharacter(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	return StringManager.startsWith(vCard.getNodeName(), "charsheet");
end

function isCardOwnedByGm(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	return StringManager.startsWith(vCard.getNodeName(), CardManager.GM_HAND_PATH);
end

function getDeckIdFromCard(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DB.getValue(vCard, "deckid", "");
end

function getDeckNodeFromCard(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DB.findNode(CardManager.getDeckIdFromCard(vCard));
end

function getDeckNameFromCard(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DB.getValue(vCard, "deckname", "");
end

function doesCardComeFromDeck(vDeck, vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return CardManager.getDeckIdFromCard(vCard) == CardManager.getDeckId(vDeck) and
		   CardManager.getDeckNameFromCard(vCard) == CardManager.getDeckName(vDeck);
end

function getCardBack(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DeckManager.getDecksCardBack(CardManager.getDeckIdFromCard(vCard));
end

function getCardFront(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DB.getValue(vCard, "image", "");
end

function getCardName(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DB.getValue(vCard, "name", "");
end

function getCardSource(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	if CardStorage.doesCardComeFromStorage(vCard) then
		return "storage";
	end

	if CardManager.isCardInHand(vCard) then
		if StringManager.startsWith(vCard.getNodeName(), "charsheet") then
			return vCard.getChild("...").getName();
		end
	end

	return "gm";
end

function getActorHoldingCard(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	if not CardManager.isCardOwnedByCharacter(vCard) then
		return;
	end

	return ActorManager.resolveActor(vCard.getChild("..."));
end

function isActorHoldingCard(vCard, rActor)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	if not DeckedOutUtilities.validateParameter(rActor, "rActor") then return false end

	-- Check if the source is the GM or storage
	local sSource = CardManager.getCardSource(vCard)
	if sSource == "gm" or sSource == "storage" then
		return false;
	end

	return rActor.sCreatureNode == DB.getPath("charsheet", sSource);
end

------------------------------------------
-- DRAG DROP
------------------------------------------
function onDragFromDeck(vDeck, draginfo)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	CardManager.onDragCard(DeckManager.drawCard(vDeck), draginfo);
end

function onDragCard(vCard, draginfo)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	draginfo.setType("shortcut");
	draginfo.setShortcutData("card", vCard.getPath());
	draginfo.setTokenData(DB.getValue(vCard, "image", ""))
	draginfo.setDescription(DB.getValue(vCard, "name", ""));
end

-- vDestination in this case should be the Node of the thing that's holding the card
-- i.e. the charsheet record. it should NOT be the charsheet.cards node
function onDropCard(draginfo, vDestination, sExtra)
	if not draginfo then
		Debug.console("ERROR: CardManager.onDropCard(): draginfo was nil or not found.");
		return;
	end
	local vDestination = DeckedOutUtilities.validateNode(vDestination, "vDestination");
	if not vDestination then return end

	-- Only handle shortcut drops
	if not draginfo.isType("shortcut") then
		return;
	end

	local sClass,sRecord = draginfo.getShortcutData();
	-- Only handle card drops
	if sClass ~= "card" then
		return;
	end

	-- If this item was dragged from card storage (i.e. the chat) then do nothing
	-- Items in chat should never be moved or handled by anything, they're read only
	if CardStorage.doesCardComeFromStorage(sRecord) then
		Debug.console("WARNING: Tried to drag/drop a card from chat. Card links in chat cannot be moved and are read-only.");
		return;
	end

	sDestPath = vDestination.getNodeName();

	if not Session.IsHost then
		CardManager.sendCardDropMessage(sRecord, sDestPath, sExtra);
		return true;
	end

	return CardManager.handleAnyDrop(sRecord, sDestPath, sExtra);
end

function handleAnyDrop(sSourceNode, sDestinationNode, sExtra)
	vCard = DeckedOutUtilities.validateNode(sSourceNode, "sSourceNode");
	vDestination = DeckedOutUtilities.validateNode(sDestinationNode, "sDestinationNode");
	if not (vCard and vDestination) then return false end
	
	local sDestination = "";
	local sReceivingIdentity = "";

	-- Dropped on a charater sheet
	if StringManager.startsWith(vDestination.getNodeName(), "charsheet") then
		-- If vDestination isn't the hand path, then get the hand path
		if vDestination.getName() ~= CardManager.PLAYER_HAND_PATH then
			vDestination = CardManager.getHandNode(vDestination.getName());
		end
		
		-- After the above, vDestination is the cards node for the character (charsheet.*.cards)
		sReceivingIdentity = vDestination.getParent().getName();

	elseif StringManager.startsWith(vDestination.getNodeName(), CardManager.GM_HAND_PATH) then
		vDestination = CardManager.getHandNode("gm");
		sReceivingIdentity = "gm"

	elseif StringManager.startsWith(vDestination.getNodeName(), "combattracker") then
		if ActorManager.isPC(vDestination) then
			-- If dropping on PC, give card to that PC
			sReceivingIdentity = ActorManager.getCreatureNode(vDestination).getName();
			vDestination = CardsManager.getHandNode(sReceivingIdentity);
		else
			-- If dropping on NPC, give card to GM
			vDestination = CardManager.getHandNode("gm");
			sReceivingIdentity = "gm"
		end

	elseif StringManager.startsWith(vDestination.getNodeName(), "deckbox") then
		-- Check that the card being dropped belongs in this deck
		if CardManager.getDeckIdFromCard(vCard) ~= DeckManager.getDeckId(vDestination) then
			Debug.console("WARNING: CardManager.handleAnyDrop(): Tried to move a card to another deck.")
			return;
		end

		-- Currently we only care about if sExtra for dropping on to the discard
		-- which currently thing does.
		if sExtra == DeckManager.DECK_DISCARD_PATH then
			vDestination = vDestination.getChild(DeckManager.DECK_DISCARD_PATH);
		else
			vDestination = vDestination.getChild(DeckManager.DECK_CARDS_PATH);
		end
	end

	-- Check if a the source of the card is the same as the destination
	-- and if it is, bail.
	local sourceParentNode = vCard.getParent();
	if sourceParentNode.getNodeName() == vDestination.getNodeName() then
		Debug.console("WARNING: CardManager.handleAnyDrop(): Tried to move a card to the same place it originated from.")
		return true;
	end

	if vDestination then
		tEventTrace = {}; -- We have to new up the table here since dropping is guaranteed to be the first in any chain of events

		if (sReceivingIdentity or "") ~= "" then
			-- If the card being dropped is currently in a hand, then we fire the give event
			if CardManager.isCardInHand(vCard) then
				local sGiverIdentity = CardManager.getCardSource(vCard);
				tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_GIVEN);
				local card = CardManager.addCardToHand(vCard, sReceivingIdentity, tEventTrace);
				DeckedOutEvents.raiseOnGiveCardEvent(card.getNodeName(), sGiverIdentity, sReceivingIdentity, tEventTrace)
				return true;

			-- If the card being dropped is currently in a deck or discard pile, we fire the deal event
			elseif CardManager.isCardInDeck(vCard) or CardManager.isCardDiscarded(vCard) then
				tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_DEALT);
				local card = CardManager.addCardToHand(vCard, sReceivingIdentity, tEventTrace);
				DeckedOutEvents.raiseOnDealCardEvent(card.getNodeName(), sReceivingIdentity, tEventTrace)
				return true;
			end
		else
			local card = CardManager.moveCard(vCard, vDestination, tEventTrace);
			return true;
		end
	end

	return false;
end

function sendCardDropMessage(sSourceNode, sDestinationNode, sExtra)
	-- The GM shouldn't be here, only clients should be sending this message
	if Session.IsHost then
		return;
	end

	local msgOOB = {};
	msgOOB.type = CardManager.OOB_MSGTYPE_DROPCARD;
	msgOOB.sSourceNode = sSourceNode;
	msgOOB.sDestinationNode = sDestinationNode;
	msgOOB.sExtra = sExtra;

	Comm.deliverOOBMessage(msgOOB, "");
end

function handleCardDrop(msgOOB)
	-- Only the GM should be handling drops, becuase this usually means moving around data
	-- Which only the GM can do anyway
	if not Session.IsHost then
		return;
	end

	CardManager.handleAnyDrop(msgOOB.sSourceNode, msgOOB.sDestinationNode, msgOOB.sExtra);
end