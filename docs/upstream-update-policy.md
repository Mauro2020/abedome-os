# Politica di aggiornamento upstream

## Fonte

La fonte ufficiale è `home-assistant/operating-system`. La baseline integrata di
ABEDOME OS è il tag ufficiale firmato registrato in `UPSTREAM.json`.

## Proposta automatica

Il workflow `propose-upstream-release.yml` gira ogni lunedì e può essere avviato
manualmente. Controlla l'ultima release ufficiale HAOS e apre o aggiorna una
pull request in stato draft verso `abedome/develop`.

La pipeline:

- accetta solo un tag ufficiale annotato la cui firma risulta verificata;
- parte sempre dall'ultimo commit di `abedome/develop` e crea un vero merge a
  due genitori con il commit ufficiale;
- aggiorna `UPSTREAM.json` dentro lo stesso merge usando esclusivamente i
  metadati presenti nella base ABEDOME protetta;
- interrompe la proposta in caso di conflitti, tag incoerente o modifica
  concorrente del branch di integrazione;
- usa un branch di proposta immutabile identificato da release e commit base;
- non esegue merge;
- non crea una release ABEDOME;
- non modifica `abedome/develop`;
- non riscrive mai un branch già revisionato;
- non esegue automaticamente codice proveniente dalla proposta.

Quando il token Actions apre la draft PR, GitHub accoda i normali workflow
`pull_request` in stato di approvazione richiesta. Il responsabile deve prima
controllare il diff e poi selezionare **Approve workflows to run**. Non vengono
usati dispatch diretti sul branch candidato.

Non esiste alcun merge automatico dall'upstream: ogni aggiornamento richiede approvazione esplicita ABEDOME.

## Requisito di ascendenza Git

Le PR di sincronizzazione upstream devono essere unite con **merge commit**.
Squash e rebase eliminerebbero dal branch prodotto l'ascendenza del tag
ufficiale e farebbero riproporre lo stesso aggiornamento.

Prima di unire una PR upstream, nelle impostazioni GitHub del repository devono
essere abilitati i merge commit. Il ruleset `Protect ABEDOME integration` deve
consentire esclusivamente `merge`; squash e rebase devono restare disabilitati
per tutte le PR dirette a `abedome/develop`.

I permessi predefiniti di Actions restano in sola lettura. Deve essere abilitata
l'opzione **Allow GitHub Actions to create and approve pull requests** soltanto
per permettere al workflow attendibile di aprire la draft PR: l'automazione non
approva e non unisce mai la proposta. Il job di proposta richiede soltanto
`contents: write` e `pull-requests: write`. Se l'impostazione non è abilitata,
GitHub rifiuta la creazione della PR e il workflow termina senza modificare
`abedome/develop`.

I branch automatici seguono la forma
`automation/upstream-haos-<release>-<base-sha>`. Se la base cambia, viene creata
una nuova proposta; quella precedente non viene forzata o riutilizzata.

## Approvazione

Una proposta può essere portata avanti solo dopo:

1. revisione del changelog e della sicurezza;
2. revisione del diff prima di approvare l'esecuzione dei workflow GitHub;
3. build completa dell'immagine per l'hardware supportato;
4. test di installazione e aggiornamento;
5. verifica che configurazione e branding ABEDOME siano applicati correttamente;
6. approvazione esplicita del responsabile ABEDOME.

## Eccezioni

Un aggiornamento di sicurezza urgente segue la stessa procedura, ma può avere priorità. Non deve mai saltare build, test o approvazione.
