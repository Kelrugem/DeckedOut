OOB_MSGTYPE_PRINTCARDPLAYED = "printcardplayed";
OOB_MSGTYPE_PRINTCARDDISCARDED = "printcarddiscarded";
OOB_MSGTYPE_PRINTCARDGIVEN = "printcardgiven";
OOB_MSGTYPE_PRINTCARDDEALT = "printcarddealt";

-- All of these message events need to start from the host because the host needs to add any cards to storage before sending out another OOB
-- That second OOB message is the one that actually prints to chat
function onInit()
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_CARD_PLAYED, { fCallback = printCardPlayedMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_CARD_DISCARDED, { fCallback = printCardDiscardedMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_CARD_GIVEN, { fCallback = printCardGivenMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_CARD_DEALT, { fCallback = printCardDealtMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_HAND_DISCARDED, { fCallback = printHandDiscardedMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_MULTIPLE_CARDS_DEALT, { fCallback = printMultipleCardsDealtMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_GROUP_DEAL, { fCallback = printGroupDealMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_HAND_PUT_BACK_IN_DECK, { fCallback = printHandPutBack, sTarget = "host" });

	-- These oob messages are needed because cards are printed to chat. the GM must copy referenced cards to card storage
	-- Before sending the message to chat. Clients can't copy to storage.
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_PRINTCARDPLAYED, DeckedOutMessages.printCardPlayedHandler);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_PRINTCARDDISCARDED, DeckedOutMessages.printCardDiscardedHandler);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_PRINTCARDGIVEN, DeckedOutMessages.printCardGivenHandler);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_PRINTCARDDEALT, DeckedOutMessages.printCardDealtHandler);
end

-----------------------------------------------------
-- PLAYING CARDS
-----------------------------------------------------
function printCardPlayedMessage(tEventArgs, tEventTrace)
	local vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	if not vCard then return end

	local bFacedown = tEventArgs.bFacedown == "true";
	local sCardSource = CardManager.getCardSource(vCard);
	if sCardSource == "storage" then return end

	-- In this case, everything is public so the two messages can be the same
	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_PRINTCARDPLAYED;
	msg.sender = sCardSource;
	msg.action = "play";

	local sTextRes = "";
	if bFacedown then
		msg.text = Interface.getString("chat_msg_card_played_facedown");
	else
		msg.text = Interface.getString("chat_msg_card_played_faceup");
	end

	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]");
	msg.card_link = vCard.getNodeName();

	Comm.deliverOOBMessage(msg, "");
end

function printCardPlayedHandler(msgOOB)
	-- Only the GM should be handling this event
	if not Session.IsHost then
		return;
	end

	-- Before we do anything else, we need to copy the card link
	-- into card storage
	local newCard = CardStorage.addCardToStorage(msgOOB.card_link);
	msgOOB.card_link = newCard.getNodeName();

	sendMessageToGm(msgOOB);
	sendMessageToClients(msgOOB);
end
-----------------------------------------------------
-- DISCARDING CARDS
-----------------------------------------------------
function printCardDiscardedMessage(tEventArgs, tEventTrace)
	if not DeckedOutUtilities.validateIdentity(tEventArgs.sSender) then return end
	vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	if not vCard then return end

	-- If the event trace already contains the discard hand event, then we don't want to print out any messages, so we bail
	if DeckedOutEvents.doesEventTraceContain(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_HAND_DISCARDED) then
		return;
	end

	local bFacedown = tEventArgs.bFacedown == "true";

	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_PRINTCARDDISCARDED;
	msg.sender = tEventArgs.sSender;
	msg.action = "discard";

	local sTextRes = "";
	if bFacedown then
		msg.text = Interface.getString("chat_msg_card_discarded_facedown");
	else
		msg.text = Interface.getString("chat_msg_card_discarded_faceup");
	end

	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]");
	msg.card_link = vCard.getNodeName();

	Comm.deliverOOBMessage(msg, "");
end

function printCardDiscardedHandler(msgOOB)
	-- Only the GM should be handling this event
	if not Session.IsHost then
		return;
	end

	-- Before we do anything else, we need to copy the card link
	-- into card storage
	local newCard = CardStorage.addCardToStorage(msgOOB.card_link);
	msgOOB.card_link = newCard.getNodeName();

	sendMessageToGm(msgOOB);
	sendMessageToClients(msgOOB);
end

-- This is configured to run only on the host
-- No cards are posted in chat so no need for an OOB message
function printHandDiscardedMessage(tEventArgs, tEventTrace)
	if not DeckedOutUtilities.validateParameter(tEventArgs.sIdentity, "sIdentity") then
		return;
	end

	local msg = {};
	msg.sender = tEventArgs.sIdentity;
	msg.text = Interface.getString("chat_msg_discarded_hand");
	msg.text = string.format(msg.text, "[SENDER]", "[PRONOUN]")

	sendMessageToGm(msg);
	sendMessageToClients(msg);
end

function printHandPutBack(tEventArgs, tEventTrace)
	if not DeckedOutUtilities.validateIdentity(tEventArgs.sIdentity) then return end;
	local vDeck = DeckedOutUtilities.validateDeck(tEventArgs.sDeckNode);

	local sDeckName = "the deck";
	if vDeck then
		sDeckName = DeckManager.getDeckName(vDeck);
	end

	local msg = {};
	msg.sender = tEventArgs.sIdentity;
	msg.text = Interface.getString("chat_msg_hand_put_back_in_deck");
	msg.text = string.format(msg.text, "[SENDER]", "[PRONOUN]", sDeckName)

	sendMessageToGm(msg);
	sendMessageToClients(msg);
end

-----------------------------------------------------
-- GIVING AND DEALING CARDS TO ONE PERSON
-----------------------------------------------------
function printCardGivenMessage(tEventArgs, tEventTrace)
	local vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	if not vCard then return end

	local bFacedown = tEventArgs.bFacedown == "true";
	local sCardSource = CardManager.getCardSource(vCard);
	if (not sCardSource) or sCardSource == "storage" then
		return;
	end

	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_PRINTCARDGIVEN;
	msg.sender = tEventArgs.sGiver;
	msg.receiver = tEventArgs.sReceiver;
	msg.card_link = vCard.getNodeName();
	msg.action = "give";
	if bFacedown then
		msg.text = Interface.getString("chat_msg_give_card_facedown");
		msg.hide_card = "true";
	else
		msg.text = Interface.getString("chat_msg_give_card_faceup");
	end

	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]", "[PRONOUN]");

	Comm.deliverOOBMessage(msg, "");
end

function printCardGivenHandler(msgOOB)
	-- Only the GM should be handling this event
	if not Session.IsHost then
		return;
	end

	-- Before we do anything else, we need to copy the card link
	-- into card storage
	local newCard = CardStorage.addCardToStorage(msgOOB.card_link);
	msgOOB.card_link = newCard.getNodeName();

	sendMessageToGm(msgOOB);
	sendMessageToClients(msgOOB);
end

function printCardDealtMessage(tEventArgs, tEventTrace)
	-- If the event trace already contains the deal multiple cards event, then we don't want to print out any messages, so we bail
	if DeckedOutEvents.doesEventTraceContain(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_MULTIPLE_CARDS_DEALT) then
		return;
	end

	local vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	if not vCard then return end

	local sCardSource = CardManager.getCardSource(vCard);
	if (not sCardSource) or sCardSource == "storage" then
		return;
	end

	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_PRINTCARDDEALT;
	-- The GM should always be the card source here. 
	-- If we use value returned from getCardSource, 
	-- it will always say the PC since we dealt them the card prior to this event
	msg.sender = "gm"; 
	msg.receiver = tEventArgs.sReceiver;
	msg.card_link = vCard.getNodeName();
	msg.action = "deal";
	
	msg.text = Interface.getString("chat_msg_deal_card");
	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]", "[PRONOUN]");
	msg.hide_card = "true";

	Comm.deliverOOBMessage(msg, "");
end

function printCardDealtHandler(msgOOB)
	-- Only the GM should be handling this event
	if not Session.IsHost then
		return;
	end

	-- Before we do anything else, we need to copy the card link
	-- into card storage
	local newCard = CardStorage.addCardToStorage(msgOOB.card_link);
	msgOOB.card_link = newCard.getNodeName();

	sendMessageToGm(msgOOB);
	sendMessageToClients(msgOOB);
end

function printMultipleCardsDealtMessage(tEventArgs, tEventTrace)
	-- If the event trace already contains the group deal cards event, then we don't want to print out any messages, so we bail
	if DeckedOutEvents.doesEventTraceContain(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_GROUP_DEAL) then
		return;
	end

	local nCardsDealt = tEventArgs.nCardsDealt;
	local sCardPlural = "card";
	if (tonumber(nCardsDealt) or 0) ~= 1 then
		sCardPlural = "cards";
	end

	local msg = {};
	-- The GM should always be the card source here. 
	-- If we use value returned from getCardSource, 
	-- it will always say the PC since we dealt them the card prior to this event
	msg.sender = "gm"; 
	msg.receiver = tEventArgs.sReceiver;
	
	msg.text = Interface.getString("chat_msg_deal_multiple_cards");
	msg.text = string.format(msg.text, "[SENDER]", nCardsDealt, sCardPlural, "[PRONOUN]");

	sendMessageToGm(msg);
	sendMessageToClients(msg);
end

-----------------------------------------------------
-- DEALING CARDS TO GROUP
-----------------------------------------------------
function printGroupDealMessage(tEventArgs, tEventTrace)
	local nCardsDealt = tEventArgs.nCardsDealt;
	local sCardPlural = "card";
	if (tonumber(nCardsDealt) or 0) ~= 1 then
		sCardPlural = "cards";
	end

	local msg = {};
	-- The GM should always be the card source here
	msg.sender = "gm"; 
	
	msg.text = Interface.getString("chat_msg_group_deal");
	msg.text = string.format(msg.text, "[SENDER]", nCardsDealt, sCardPlural);

	sendMessageToGm(msg);
	sendMessageToClients(msg);
end

-----------------------------------------------------
-- NOTIFICATIONS
-----------------------------------------------------
function printNotEnoughCardsInDeckMessage(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local msg = {};

	local sDeckName = DeckManager.getDeckName(vDeck);
	msg.text = string.format(Interface.getString("chat_msg_not_enough_cards_in_deck"), sDeckName);
	msg.font = "systemfont";

	Comm.addChatMessage(msg)
end

-----------------------------------------------------
-- HELPERS
-----------------------------------------------------
function getUserDisplayNameForCard(vCard)
	if Session.IsHost then
		return "The GM";
	else
		return ActorManager.getDisplayName(CardManager.getActorHoldingCard(vCard));
	end
end

function resolveIdentityName(sIdentity, sMessageIdentity)
	if not sIdentity then
		return nil;
	end
	if sIdentity == sMessageIdentity then
		return "you";
	end
	if sIdentity == "gm" then
		return "the GM";
	else
		return ActorManager.getDisplayName(
			ActorManager.resolveActor(
				DB.findNode(
					DB.getPath("charsheet", sIdentity))));
	end
end

function resolvePronouns(sSender, sReceiver, sMessageId, sDefault)
	if (sReceiver or "") == "" then
		-- If there is no receiver, then we only use 'your', 'their', and 'name'
		if sSender == sMessageId then
			return "your";
		elseif (sDefault or "") == "" then
			return "their";
		end
	else
		-- If there is a receiver, then we use 'yourself, 'themselves', and 'name
		if sSender == sReceiver and sSender == sMessageId then
			return "yourself";
		end
		if sReceiver == sMessageId then
			return "you";
		elseif sSender == sReceiver then
			return "themselves";
		end
	end
	return sDefault;
end

-- Returns true if the card is visible, and false if not visible
function resolveCardVisibility(msg, sSenderName, sReceiverName, sMessageId)
	local sSetting = nil;

	local vDeck = CardManager.getDeckNodeFromCard(msg.card_link);
	if not vDeck then return true end -- Would be weird if this happened

	if msg.action == "deal" then
		sSetting = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_DEAL_VISIBILITY);
	elseif msg.action == "play" then
		sSetting = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_PLAY_VISIBILITY);
	elseif msg.action == "give" then
		sSetting = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_GIVE_VISIBILITY);
	elseif msg.action == "discard" then
		sSetting = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_DISCARD_VISIBILITY);
	end

	-- If no action is present, then return false. i.e Card is not hidden
	if not sSetting then
		return true;
	end

	-- If only the person giving/receiving a card should see the card
	-- Then we only return true when the sender is 'you'
	if sSetting == "actor" then
		-- Dealing cards is the one edge case, because the GM is always the sender
		if msg.action == "deal" then
			return sReceiverName == "you";
		end
		return sSenderName == "you" or sReceiverName == "you";
	elseif sSetting == "gmandactor" then
		return sMessageIdentity == "gm" or sSenderName == "you" or sReceiverName == "you";
	end

	-- If we get here and sSetting is not everyone, then something went wrong
	if sSetting ~= "everyone" then
		Debug.console("ERROR: Deck setting for action '" .. msg.action .. "' was set to " .. sSetting .. " when 'everyone' was expected");
	end
	return sSetting == "everyone";
end

function formatChatMessage(msgOOB, sMessageId)
	local sText = msgOOB.text;
	local sSenderName = resolveIdentityName(msgOOB.sender, sMessageId);
	local sReceiverName = resolveIdentityName(msgOOB.receiver, sMessageId);
	local bShowCard = false

	local sPronoun = resolvePronouns(msgOOB.sender, msgOOB.receiver, sMessageId, sReceiverName);

	local sCardName = nil;
	if msgOOB.card_link then
		sCardName = CardManager.getCardName(msgOOB.card_link);
		bShowCard = resolveCardVisibility(msgOOB, sSenderName, sReceiverName, sMessageId)
		
		if not bShowCard then
			sCardName = "a card";
		end
	end
	
	if sSenderName then
		sText = sText:gsub("%[SENDER%]", sSenderName);
	end
	if sReceiverName then
		sText = sText:gsub("%[RECEIVER%]", sReceiverName);
	end
	if sCardName then
		sText = sText:gsub("%[CARDNAME%]", sCardName);
	end
	if sPronoun then
		sText = sText:gsub("%[PRONOUN%]", sPronoun)
	end

	-- Capitalize the first letter of the text
	sText = (sText:gsub("^%l", string.upper))

	return sText, bShowCard;
end


function buildCardMessage(msgOOB, sRecipientIdentity)
	local msg = {};

	-- TODO: Add an extra icon here based on msg.action
	if msgOOB.sender == "gm" then
		msg.icon = "portrait_gm_token";
	else
		local nodeActor = DB.findNode(DB.getPath("charsheet", msgOOB.sender));
		if nodeActor then
			msg.icon = "portrait_" .. nodeActor.getName() .. "_chat";
		end
	end

	local sText, bShowCard = formatChatMessage(msgOOB, sRecipientIdentity);
	if bShowCard and msgOOB.card_link then
		msg.shortcuts = {}
		table.insert(msg.shortcuts, { description = sText, class = "card", recordname = msgOOB.card_link });
	end

	msg.text = sText;
	msg.font = "systemfont";

	return msg;
end

function sendMessageToGm(msgOOB)
	local msg = buildCardMessage(msgOOB, "gm");
	Comm.deliverChatMessage(msg, "");
end

function sendMessageToClients(msgOOB)
	local aUsers = User.getActiveUsers();
	for k,user in ipairs(aUsers) do
		-- This could get weird if for some reason a player has 2 identities
		-- and they send a message with one but receive it on the other
		-- I can't imagine how that would happen, but it would be weird.
		local sCurrentId = User.getCurrentIdentity(user);
		local msg = buildCardMessage(msgOOB, sCurrentId);
		Comm.deliverChatMessage(msg, user)
	end
end