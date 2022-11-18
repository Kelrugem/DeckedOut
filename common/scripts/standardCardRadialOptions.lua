function onInit()
	if super and super.onInit then
		super.onInit();
	end

	local card = window.getDatabaseNode();
	
	registerMenuItem(Interface.getString("card_menu_play_face_up"), "play_faceup", 1);
	registerMenuItem(Interface.getString("card_menu_play_face_down"), "play_facedown", 5)
	if not CardManager.isCardInDeck(card) then
		registerMenuItem(Interface.getString("card_menu_reshuffle"), "reshuffle_card", 6)
	end
	if not CardManager.isCardDiscarded(card) then
		registerMenuItem(Interface.getString("card_menu_discard_card"), "discard_card", 7);
	end

	DeckedOutUtilities.addOnCardFlippedHandler(card, onCardFlipped);
	onCardFlipped();
end

function onClose()
	if super and super.onClose then
		super.onClose();
	end
	DeckedOutUtilities.removeOnCardFlippedHandler(card, onCardFlipped);
end

function onCardFlipped()
	local vCard = window.getDatabaseNode();
	if not CardManager.isCardInHand(vCard) then
		return;
	end

	local text;
	if CardManager.isCardFaceUp(vCard) then	
		text = Interface.getString("card_menu_flip_facedown");
	else
		text = Interface.getString("card_menu_flip_faceup");
	end

	if text then
		registerMenuItem(text, "flip", 3);
	end
end

function onMenuSelection(selection)
	if selection == 1 then
		playCard(DeckedOutUtilities.getFacedownHotkey())
	elseif selection == 3 then
		CardManager.flipCardFacing(window.getDatabaseNode(), {})
	elseif selection == 5 then
		playCard(true);
	elseif selection == 6 then
		CardManager.putCardBackInDeck(window.getDatabaseNode(), DeckedOutUtilities.getFacedownHotkey(), {});
	elseif selection == 7 then
		-- We pass in nil for sIdentity because discardCard gets the user identity for us
		CardManager.discardCard(window.getDatabaseNode(), DeckedOutUtilities.getFacedownHotkey(), nil, {});
	end
end

function onDoubleClick(x, y)
	playCard(DeckedOutUtilities.getFacedownHotkey());
end

function playCard(bFacedown)
	local vCard = window.getDatabaseNode();
	local vDeck = CardManager.getDeckNodeFromCard(vCard);

	local bDiscard = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_AUTO_PLAY_FROM_HAND) == "yes"
	CardManager.playCard(vCard, bFacedown, bDiscard or DeckedOutUtilities.getPlayAndDiscardHotkey(), {});
end