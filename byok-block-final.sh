#!/bin/sh
source env.txt
IAM_TOKEN=""
PASS_PHRASE=""

getIAMToken()
{
	CMD="curl --silent -X POST $IAM_URI -H 'Content-Type: application/x-www-form-urlencoded' -H 'Accept: application/json' -d 'grant_type=urn%3Aibm%3Aparams%3Aoauth%3Agrant-type%3Aapikey&apikey=$IAM_SERVICE_ID_API_KEY'"
	IAM_TOKEN=$(eval "$CMD")
	OUT=$?
	if [ $OUT -eq 0 ];then
   	  echo "Token created"
      IAM_TOKEN=$(echo $IAM_TOKEN | jq -r '.access_token')
	else
   	  echo "Token create failue"
	  exit 1
	fi
}

## this will use the Root key in Keyprotect to get a new wrapped DEK and stores in a File
getwrappedDEK()
{
	getIAMToken
	#echo $IAM_TOKEN
	ACTION="$KP_API_URI$KP_ROOT_KEY_ID?action=wrap"
	CMD="curl --silent -X POST $ACTION -H 'authorization: Bearer $IAM_TOKEN' -H 'accept: application/vnd.ibm.collection+json' -H 'bluemix-instance: $KP_INSTANCE_ID' -d '{}'"
        echo $CMD
	KEY=$(eval "$CMD")
        OUT=$?
        if [ $OUT -eq 0 ];then
          CIPHER=$(echo $KEY | jq -r '.ciphertext')
          echo  $CIPHER > $WRAPPED_DEK_FILE
          echo "Key retrival success"
        else
          echo "Key retrival failed"
          exit 1
        fi
}

unwrapDEK()
{
  if [ ! -f "$WRAPPED_DEK_FILE" ]; then
	    echo "$WRAPPED_DEK_FILE not found aborting"
	    exit 2
	fi
	getIAMToken
  #echo $IAM_TOKEN
  ACTION="$KP_API_URI$KP_ROOT_KEY_ID?action=unwrap"
  #echo $ACTION
	CIPHER_TXT=$(cat $WRAPPED_DEK_FILE)
	echo $CIPHER_TXT
  CMD="curl --silent -X POST $ACTION -H 'authorization: Bearer $IAM_TOKEN' -H 'accept: application/vnd.ibm.collection+json' -H 'bluemix-instance: $KP_INSTANCE_ID' -d '{\"ciphertext\":\"$CIPHER_TXT\"}'"
  echo $CMD
  KEY=$(eval "$CMD")
	OUT=$?
  if [ $OUT -eq 0 ];then
    PASS_PHRASE=$(echo $KEY | jq -r '.plaintext')
    #echo $PASS_PHRASE
    echo "Key retrival success"
  else
      echo "Key retrival failed"
      exit 1
  fi
}

case "$1" in
create)	echo  "create encrypted partition"
        iscsiadm -m node --login
	      # here we need to call KP
	      #  check if mapping already exist and call luksClose
	      umount /dev/mapper/$CRYPT_MAP
	      cryptsetup luksClose /dev/mapper/$CRYPT_MAP
	      getwrappedDEK
	      unwrapDEK
	      echo -n $PASS_PHRASE | cryptsetup luksFormat $PARTITION -c aes -s 256 -h sha256 -d -
	      echo -n $PASS_PHRASE | cryptsetup luksOpen $PARTITION $CRYPT_MAP -d -
	      unset PASS_PHRASE
	      mkfs.ext4 /dev/mapper/$CRYPT_MAP
	      ;;
mount)	echo "mount encrypted partition"
	      unwrapDEK
	      iscsiadm -m node --login
	      echo -n $PASS_PHRASE | cryptsetup luksOpen $PARTITION $CRYPT_MAP -d -
	      unset PASS_PHRASE
	      mount /dev/mapper/$CRYPT_MAP /data
	      exit 0;
        ;;
umount)echo "unmount encrypted partition"
        umount /dev/mapper/$CRYPT_MAP
	      cryptsetup luksClose /dev/mapper/$CRYPT_MAP
	      exit 0;
        ;;
delete) echo "delete encrypted partition"
        unwrapDEK
	      umount /dev/mapper/$CRYPT_MAP
        cryptsetup luksClose /dev/mapper/$CRYPT_MAP
        echo -n $PASS_PHRASE | cryptsetup luksRemoveKey $PARTITION -d -
	      cryptsetup remove $PARTITION
	      rm $WRAPPED_DEK_FILE
	      exit 0;
        ;;
test) 	echo "test"
        getwrappedDEK
        unwrapDEK
        exit 0;
        ;;
*)	echo  "Usage: {create|mount|umount|delete|test}"
        exit 2
        ;;
esac
exit 0
