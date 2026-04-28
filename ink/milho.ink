// Quête "vendre du milho sur la plage"
// Compile via inkgd (import automatique) ou inklecate.
// Les fonctions externes sont implémentées dans scripts/quests/DialogueBridge.gd.

EXTERNAL accept_quest(quest_id)
EXTERNAL complete_objective(quest_id, objective_id)
EXTERNAL modify_reputation(axis, delta)
EXTERNAL add_money(amount)
EXTERNAL sell_corn(price)
EXTERNAL give_corn()
EXTERNAL return_cart()

VAR player_has_accepted = false

// ----------------------------------------------------------------------------
// Seu João — 3 états : intro (avant quête), rappel (quête active, sans charrette),
// retour (quête active, charrette portée).

=== seu_joao_intro ===
Seu João: E aí, meu parceiro ! Tá querendo ganhar um troco hoje ?
Seu João: Tenho uma carrocinha de milho aqui, mas meu joelho não deixa eu andar no sol.
* [Aceitar le boulot] -> sj_accept
* [Combien je touche ?] -> sj_haggle
* [Pas aujourd'hui] -> sj_decline

=== sj_haggle ===
Seu João: Trinta pour cent du chiffre. C'est la règle de la plage.
* [Topo] -> sj_accept
* [Je réfléchis] -> sj_decline

=== sj_accept ===
~ accept_quest("quest_milho_01")
~ player_has_accepted = true
Seu João: Massa ! Pega a carrocinha ali e se vira.
Seu João: Se um PM te parar, se vira sozinho. Eu não tenho nada a ver.
-> END

=== sj_decline ===
Seu João: Tranquilo. Passa aí outro dia se mudar de ideia.
-> END

=== seu_joao_reminder ===
Seu João: Vai pegar a carrocinha, parceiro. Tá ali, na areia.
-> END

=== seu_joao_return ===
Seu João: E aí ! Tudo certo ? Deixa eu ver a carrocinha.
* [Rendre la charrette]
    ~ return_cart()
    Seu João: Bom trabalho, parceiro. Até a próxima.
    -> END
* [Encore une tournée]
    Seu João: Manda ver.
    -> END

// ----------------------------------------------------------------------------
// Ventes — appelées via CustomerNPC selon l'archétype.

=== haggle_with_tourist ===
Gringa: How much for the corn?
* [Cinco reais (prix juste)]
    ~ sell_corn(5)
    ~ modify_reputation(0, 1)
    Gringa: Obrigada !
    -> END
* [Quinze reais (arnaque)]
    ~ sell_corn(15)
    ~ modify_reputation(0, -2)
    ~ modify_reputation(3, -3)
    Gringa: Expensive… but ok.
    -> END
* [Refuser de vendre]
    -> END

=== haggle_with_local ===
Carioca: Um milho, por favor.
* [Cinco reais]
    ~ sell_corn(5)
    ~ modify_reputation(2, 1)
    Carioca: Valeu, parceiro.
    -> END
* [Refuser]
    -> END

=== kid_asks ===
Gamin: Moço, me dá um milho ? Tô sem grana…
* [Lui offrir]
    ~ give_corn()
    ~ modify_reputation(0, 2)
    ~ modify_reputation(2, 1)
    Gamin: Valeu, mano ! Você é gente boa.
    -> END
* [Refuser]
    ~ modify_reputation(2, -1)
    -> END

// ----------------------------------------------------------------------------
// Événement PM — déclenché par un trigger de zone (à câbler plus tard).

=== cop_shakedown ===
PM: Alvará de vendedor ambulante ? Me deixa ver…
* [Payer le pot-de-vin (R$ 20)]
    ~ add_money(-20)
    ~ modify_reputation(1, 3)
    ~ modify_reputation(0, -2)
    PM: Boa tarde, cidadão.
    -> END
* [Refuser et argumenter]
    ~ modify_reputation(0, 2)
    ~ modify_reputation(1, -5)
    PM: Tá bom, tá bom. Mas eu tô de olho.
    -> END
