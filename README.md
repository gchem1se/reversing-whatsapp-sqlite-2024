# Reversing Whatsapp's SQLite (in 2024)
## Overview
This repository documents my process of trying a reverse-engineering of the database schema and key tables in WhatsApp's SQLite databases. 

It also includes some SQL queries to automate data extraction and analysis, shedding light on how you can reconstruct humanly-readable information from these files.

These are files you can access with all kinds of file manager application on your Android device after launching a backup via the application's settings menu. For the most part, you don't even need root access on your phone to reach for those.

## Validity
The information you find here are surely valid for WhatsApp's versions ranging from 2.23.XX.XX to 2.24.19.86. 

I also expect this to still be useful for researching and analyzing instances of older versions with minimal modifications. 

As this has been an individual project, I had to rely on versions I personally used and therefore had the possibility to test for. 

## Motivations
The primary goal of this project is to grant users the possibility to freely access messages they exchanged and data they generated through the app, circumventing some annoying limitations the application had since a long time.

WhatsApp's application does indeed offer an "Export Chat" feature, but that forces you to accept some constraints. [Their FAQ states](https://faq.whatsapp.com/1180414079177245/?cms_platform=android):

1. The application enables you to export a chat in a (rather ugly) `.txt` file, but if you choose to include media in the export, only the most recent media sent will be added as attachments to be sent from your sharesheet.
2. In addition to that, when exporting with media or without media, you can only get up to 100,000 latest messages to be exported.

The only other way to review some older messages would be to rely on WhatsApp's internal mechanism of handling backups and restores. That involves, in most cases, trusting a major cloud service for storing your backups, and be willing to start a recovery process that can only be triggered by deleting the application entirely and re-installing it. They do not handle different versions of the backup, so if the backup process produces a corrupted file, you will end up with nothing being restored (it actually happened to me). 
Finally, you can only do it that many times, since repeating the phone number verification process (you are asked for that during the initial setup of a freshly installed instance of the app) within limited time periods could flag you as a potentially malicious user, locking you out of your account for a day or so.

The methodology I describe and [the tool I'm developing](https://github.com/gchem1se/rechat) enable you to recover all of your conversations and media files, as well as navigate the database in an interactive way.

## Ethical considerations
This project is strictly intended for educational and research purposes.
I want to state clear that I'm not providing you any kind of way to access other people's data or breaking the encryption. 

If you do not have the encryption key (which is a 64-digits hexstring in the versions referenced here), you would have no way to access the plain messages. 

If you do happen to know the encryption key and you have access to the necessary files, you clearly have full access of the device WhatsApp is running on already, therefore, this project is not helping you further. 
