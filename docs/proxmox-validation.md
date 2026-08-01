# Prima validazione ABEDOME OS su Proxmox VE

## Decisione

La prima immagine ABEDOME OS viene validata come appliance virtuale x86-64 per Proxmox VE.

| Voce | Valore |
|---|---|
| Target HAOS | `ova` |
| Architettura | `x86_64` |
| Artefatto | `.qcow2` |
| Hypervisor | Proxmox VE |
| Firmware VM | UEFI / OVMF |

Il target `ova` produce l'immagine QCOW2 destinata ai virtualizzatori. Non va confuso con il target `generic-x86-64`, progettato per installazione diretta su hardware UEFI.

## Prima build

La prima build è una verifica dell'infrastruttura e parte dalla baseline HAOS `17.3`. Non contiene ancora personalizzazioni visive o dati ABEDOME nell'immagine.

Criteri di superamento:

1. il workflow upstream di sviluppo genera l'artefatto QCOW2;
2. la VM Proxmox si avvia con firmware UEFI;
3. Home Assistant completa l'avvio e il primo onboarding;
4. rete, console e riavvio funzionano;
5. l'artefatto e la configurazione della VM vengono annotati nella PR di validazione.

## Configurazione VM consigliata

- 2 vCPU come minimo; 4 vCPU consigliate per il test;
- 4 GB RAM consigliati;
- controller disco VirtIO SCSI;
- scheda di rete VirtIO;
- firmware OVMF/UEFI, senza Secure Boot;
- bridge di rete della LAN di test.

L'eventuale pass-through USB per Zigbee, Z-Wave o Bluetooth viene provato dopo il boot base.

## Flusso di test

1. avvia manualmente il workflow di sviluppo HAOS dal branch `abedome/develop`;
2. seleziona il target `ova`;
3. scarica e decomprimi l'artefatto QCOW2;
4. importa il disco in una VM Proxmox configurata come sopra;
5. completa l'onboarding senza usare dati di produzione;
6. registra l'esito nella pull request.

## Confini

Questa validazione non abilita ancora distribuzione a utenti finali, aggiornamenti OTA ABEDOME o personalizzazioni di Core, Supervisor e Frontend.
