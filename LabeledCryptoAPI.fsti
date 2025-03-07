/// This module presents a labeled security API for use by honest applications.
/// All data manipulated by this module is annotated with secrecy labels,
/// and all functions carefully track these labels.
/// The types for the functions can be read as labeling rules.
/// These labeling rules are themselves proved sound against the
/// Dolev-Yao model of cryptgraphy in SymbolicCrypto.fst
module LabeledCryptoAPI

open SecrecyLabels
open CryptoLib
open GlobalRuntimeLib

(* Instantiating Can Flow Relation between labels *)
let corrupt_id (i:timestamp) (x:id) =
  (exists p' s' v'. (was_corrupted_before i p' s' v' /\ covers x (V p' s' v')))
let cpred = {
  corrupt_id = corrupt_id;
  corrupt_id_later = (fun i j -> ());
  corrupt_id_covers = (fun i -> ())}
let can_flow = can_flow_p cpred
let can_flow_later = can_flow_later cpred
let can_flow_transitive = can_flow_transitive cpred
let flows_to_public_can_flow = flows_to_public_can_flow cpred
let flows_to_public_can_flow_forall = flows_to_public_can_flow_forall cpred
let can_flow_from_join = can_flow_from_join cpred
let can_flow_join_public_lemma = can_flow_join_public_lemma cpred
let can_flow_to_join_forall = can_flow_to_join_forall cpred
let can_flow_to_join_forall_trace_index = can_flow_to_join_forall_trace_index cpred
let can_flow_to_meet_forall = can_flow_to_meet_forall cpred
let can_flow_to_private = can_flow_to_private cpred
let can_flow_from_public = can_flow_from_public cpred
let can_flow_to_public_implies_corruption = can_flow_to_public_implies_corruption cpred
let includes_can_flow_lemma = includes_can_flow_lemma cpred 
let includes_corrupt_lemma = includes_corrupt_lemma cpred
let includes_corrupt_2_lemma = includes_corrupt_2_lemma cpred 
let includes_corrupt_2_lemma_forall_trace_index = includes_corrupt_2_lemma_forall_trace_index cpred
let includes_corrupt_2_lemma_forall = includes_corrupt_2_lemma_forall cpred
let can_flow_join_public_lemma_forall_trace_index = can_flow_join_public_lemma_forall_trace_index cpred
let can_flow_join_labels_public_lemma =  can_flow_join_labels_public_lemma cpred

noeq type key_usages = {
  dh_shared_secret_usage: string -> string -> shared_secret:bytes -> option usage;
  dh_unknown_peer_usage: string -> shared_secret:bytes -> option usage;
  dh_usage_commutes_lemma: unit -> Lemma (forall s1 s2 ss. dh_shared_secret_usage s1 s2 ss == dh_shared_secret_usage s2 s1 ss);
  dh_unknown_peer_usage_lemma: unit -> Lemma (forall s1 ss u. dh_unknown_peer_usage s1 ss == Some u ==> (forall s2. dh_shared_secret_usage s1 s2 ss == Some u));
  kdf_extend_label: string -> key:bytes -> salt:bytes -> label;
  kdf_extract_usage: string -> key:bytes -> salt:bytes -> option usage;
  kdf_expand_usage: string -> key:bytes -> info:bytes -> option usage;
}

let none_usage k s = None
let none_key_usages : key_usages = {
  dh_shared_secret_usage = (fun s1 s2 ss -> None);
  dh_unknown_peer_usage = (fun s1 ss -> None);
  dh_usage_commutes_lemma = (fun () -> ());
  dh_unknown_peer_usage_lemma = (fun () -> ());
  kdf_extend_label = (fun s k sal -> private_label);
  kdf_extract_usage = (fun s k slt -> None);
  kdf_expand_usage = (fun s k slt -> None);
}

(* Mapping each bytestring to unique label and optional usage *)
val get_usage: gu:key_usages -> bytes -> (option usage)
val get_label: gu:key_usages -> bytes -> label
val get_sk_label: gu:key_usages -> bytes -> label
val get_signkey_label: gu:key_usages -> bytes -> label
val get_dhkey_label: gu:key_usages -> bytes -> label

(* Usage Predicates *)
noeq type usage_preds = {
  can_pke_encrypt: nat -> bytes -> bytes -> Type0;
  can_aead_encrypt: nat -> k:bytes -> m:bytes -> ad:bytes -> Type0;
  can_sign: nat -> k:bytes -> m:bytes -> Type0;
  can_mac: nat -> k:bytes -> m:bytes -> Type0;
}
let pke_pred pr i k p = exists j. later_than i j /\ pr.can_pke_encrypt j k p
let aead_pred pr i k p ad = exists j. later_than i j /\ pr.can_aead_encrypt j k p ad
let mac_pred pr i k p = exists j. later_than i j /\ pr.can_mac j k p
let sign_pred pr i k p = exists j. later_than i j /\ pr.can_sign j k p

noeq type global_usage = {
  usage_preds: usage_preds;
  key_usages: key_usages;
}

(* Labeling Predicates *)
val is_valid: p:global_usage -> i:nat -> b:bytes -> Type0
val is_valid_later : p:global_usage -> i:nat -> j:nat -> t:bytes ->
    Lemma ((is_valid p i t /\ later_than j i) ==> (is_valid p j t))
	  [SMTPat (is_valid p i t); SMTPat (later_than j i)]

let is_labeled (p:global_usage) (i:nat) (b:bytes) (l:label) = is_valid p i b /\ get_label p.key_usages b == l
let is_secret (p:global_usage) (i:nat) (b:bytes) (l:label) (u:usage) = is_labeled p i b l /\ get_usage p.key_usages b == Some u
let is_msg (p:global_usage) i b l = is_valid p i b /\ can_flow i (get_label p.key_usages b) l
let is_publishable (p:global_usage) i b = is_msg p i b public

let lbytes (p:global_usage) i l = b:bytes{is_labeled p i b l}
let msg (p:global_usage) i l = b:bytes {is_msg p i b l}
let secret (p:global_usage) i l u = b:bytes{ is_secret p i b l u }

(* Labeled Crypto API *)
module C = CryptoLib

val restrict: #p:global_usage -> #i:nat -> #l1:label -> t:msg p i l1 ->
	      l2:label{can_flow i l1 l2} -> t':msg p i l2{t' == t}

val rand_is_secret : #p:global_usage -> #i:nat -> #l:label -> #u:usage -> r:bytes -> Lemma (was_rand_generated_before i r l u ==> is_secret p i r l u)

val literal_to_bytes: #p:global_usage -> #i:nat -> s:literal -> msg p i public
val literal_to_bytes_lemma: #p:global_usage -> #i:nat -> s:literal ->
  Lemma (ensures (literal_to_bytes #p #i s == C.literal_to_bytes s))
        [SMTPat (literal_to_bytes #p #i s)]

val bytes_to_literal: #p:global_usage -> #i:nat -> #l:label -> t:msg p i l -> result literal
val bytes_to_literal_lemma: #p:global_usage -> #i:nat -> #l:label -> t:msg p i l ->
  Lemma (match bytes_to_literal t with
	  | Success s -> C.bytes_to_literal t == Success s
	  | Error e -> C.bytes_to_literal t == Error e)
	[SMTPat (bytes_to_literal t)]

let literal_to_labeled_bytes (#p:global_usage) (#i:nat) (#l:label) (s:literal) :  msg p i l =
  literal_to_bytes #p #i s


let string_to_bytes #pr #i s : msg pr i public = literal_to_bytes #pr #i (String s)
let bytes_to_string #pr #i (t:msg pr i public) : result string =
  match bytes_to_literal #pr #i #public t with
  | Success (String x) -> Success x
  | _ -> Error "not a string literal"

val concat: #p:global_usage -> #i:nat -> #l:label -> msg p i l -> msg p i l -> msg p i l
val concat_lemma: #p:global_usage -> #i:nat -> #l:label -> t1:msg p i l -> t2:msg p i l ->
    Lemma (ensures (concat #p #i #l t1 t2 == C.concat t1 t2))
          [SMTPat (concat #p #i #l t1 t2)]

val split: #p:global_usage -> #i:nat -> #l:label -> t:msg p i l -> result (msg p i l & msg p i l)
val split_lemma: #p:global_usage -> #i:nat -> #l:label -> t:msg p i l ->
    Lemma (match split t with
           | Error x -> C.split t == Error x
	   | Success (x,y) -> C.split t == Success (x,y))
	  [SMTPat (split t)]

let is_private_dec_key p i b l s = is_secret p i b l (pke_usage s)
let is_public_enc_key p i b l s = is_publishable p i b /\ (exists sk. is_secret p i sk l (pke_usage s) /\ b == pk sk)
let is_public_enc_key_later_lemma p i b l s : 
    Lemma (forall j. is_public_enc_key p i b l s /\ i < j ==> is_public_enc_key p j b l s) 
	  [SMTPat (is_public_enc_key p i b l s)] = assert (forall j. i < j ==> later_than j i)

type private_dec_key p (i:nat) (l:label) s = b:bytes{is_private_dec_key p i b l s}
type public_enc_key p (i:nat) (l:label) s = b:bytes{is_public_enc_key p i b l s}

val pk: #p:global_usage -> #i:nat -> #l:label -> sk:lbytes p i l -> lbytes p i public
val pk_lemma: #p:global_usage -> #i:nat -> #l:label -> sk:lbytes p i l ->
  Lemma (ensures (pk sk == C.pk sk /\
		  (forall s. is_private_dec_key p i sk l s ==> is_public_enc_key p i (pk sk) l s /\ 
									  get_sk_label p.key_usages (pk sk) == get_label p.key_usages sk)))
        [SMTPat (pk sk)]
val sk_label_lemma : p:global_usage -> i:nat -> t:bytes -> l:label -> Lemma (forall s. is_public_enc_key p i t l s ==> get_sk_label p.key_usages t == l)

val pke_enc: #p:global_usage -> #i:nat -> 
    public_key:msg p i public ->
    message:msg p i (get_sk_label p.key_usages public_key){
      forall s. is_public_enc_key p i public_key (get_sk_label p.key_usages public_key) s ==>
	   pke_pred p.usage_preds i public_key message } ->
    msg p i public
val pke_enc_lemma: #p:global_usage -> #i:nat -> 
    pk:msg p i public -> m:msg p i (get_sk_label p.key_usages pk){forall s. is_public_enc_key p i pk (get_sk_label p.key_usages pk) s ==> pke_pred p.usage_preds i pk m} ->
  Lemma (ensures (pke_enc #p #i pk m == C.pke_enc pk m))
        [SMTPat (pke_enc #p #i pk m)]

val pke_dec: #p:global_usage -> #i:nat -> #l:label ->
    private_key:lbytes p i l{is_publishable p i private_key \/
			   (exists s. is_private_dec_key p i private_key l s)} ->
    ciphertext:msg p i public ->
    result (msg p i l)
val pke_dec_lemma: #p:global_usage -> #i:nat -> #l:label ->
    private_key:lbytes p i l{is_publishable p i private_key \/
			   (exists s. is_private_dec_key p i private_key l s)} ->
    ciphertext:msg p i public ->
    Lemma (match pke_dec private_key ciphertext with
	   | Success plaintext ->
	     C.pke_dec private_key ciphertext == Success plaintext /\
	     (forall s. is_private_dec_key p i private_key l s ==>
	     (is_publishable p i plaintext \/ pke_pred p.usage_preds i (C.pk private_key) plaintext))
           | Error x -> C.pke_dec private_key ciphertext == Error x)
	  [SMTPat (pke_dec private_key ciphertext)]

let is_aead_key p i b l s = is_secret p i b l (aead_usage s)
type aead_key p i l s = b:bytes{is_aead_key p i b l s}

val aead_enc: #p:global_usage -> #i:nat -> #l:label ->
    k:lbytes p i l{is_publishable p i k \/ (exists s. is_aead_key p i k l s)} ->
    m:msg p i l -> ad:msg p i public{forall s. is_aead_key p i k l s ==> aead_pred p.usage_preds i k m ad} ->
    msg p i public
val aead_enc_lemma: #p:global_usage -> #i:nat -> #l:label ->
    k:lbytes p i l{is_publishable p i k \/ (exists s. is_aead_key p i k l s)} ->
    m:msg p i l -> ad:msg p i public{forall s. is_aead_key p i k l s ==> aead_pred p.usage_preds i k m ad} ->
  Lemma (ensures (aead_enc k m ad == C.aead_enc k m ad))
        [SMTPat (aead_enc k m ad)]

val aead_dec: #p:global_usage -> #i:nat -> #l:label ->
    k:lbytes p i l{is_publishable p i k \/ (exists s. is_aead_key p i k l s)} ->
    c:msg p i public -> ad:msg p i public ->
    result (msg p i l)
val aead_dec_lemma: #p:global_usage -> #i:nat -> #l:label ->
    k:lbytes p i l{is_publishable p i k \/ (exists s. is_aead_key p i k l s)} ->
    c:msg p i public -> ad:msg p i public ->
    Lemma (match aead_dec k c ad with
         | Success pt -> C.aead_dec k c ad == Success pt /\
		      (is_publishable p i k \/
		       aead_pred p.usage_preds i k pt ad)
         | Error s -> C.aead_dec k c ad == Error s)
    [SMTPat (aead_dec k c ad)]

let is_signing_key p i b l s = is_secret p i b l (sig_usage s)
let is_verification_key p i b l s = is_publishable p i b /\ (exists sk. is_signing_key p i sk l s /\ b == C.vk sk)
let sign_key p i l s = b:bytes{is_signing_key p i b l s}
let verify_key p i l s = b:bytes{is_verification_key p i b l s}

val vk: #p:global_usage -> #i:nat -> #l:label -> sk:lbytes p i l -> lbytes p i public
val vk_lemma: #p:global_usage -> #i:nat -> #l:label -> sk:lbytes p i l ->
  Lemma (ensures (vk sk == C.vk sk /\ 
		  (forall s. is_signing_key p i sk l s ==> is_verification_key p i (vk sk) l s /\ (get_signkey_label p.key_usages (vk sk) == get_label p.key_usages sk))))
        [SMTPat (vk sk)]

val sign: #p:global_usage -> #i:nat -> #l:label -> #l':label ->
    k:lbytes p i l{is_publishable p i k \/ (exists s. is_signing_key p i k l s)} ->
    m:msg p i l'{forall s. is_signing_key p i k l s ==> sign_pred p.usage_preds i (C.vk k) m} ->
    msg p i l'
val sign_lemma: #p:global_usage -> #i:nat -> #l:label -> #l':label ->
    k:lbytes p i l{is_publishable p i k \/ (exists s. is_signing_key p i k l s)} ->
    m:msg p i l'{forall s. is_signing_key p i k l s ==> sign_pred p.usage_preds i (C.vk k) m} ->
  Lemma (ensures(sign k m == C.sign k m))
        [SMTPat (sign k m)]

val verify: #p:global_usage -> #i:nat -> #l1:label -> #l2:label ->
    pk:msg p i public -> m:msg p i l1 -> s:msg p i l2 -> bool
val verify_lemma: #p:global_usage -> #i:nat -> #l1:label -> #l2:label ->
    pk:msg p i public -> m:msg p i l1 -> s:msg p i l2 ->
    Lemma (if verify pk m s then
            C.verify pk m s /\
	    (forall l s. is_verification_key p i pk l s ==>
		    (can_flow i l public \/ sign_pred p.usage_preds i pk m))
         else (C.verify pk m s = false))
  [SMTPat (verify pk m s)]

val verification_key_label_lemma : p:global_usage -> i:nat -> t:bytes -> l:label -> Lemma (forall s. is_verification_key p i t l s ==> get_signkey_label p.key_usages t == l)

let is_mac_key p i b l s = is_secret p i b l (mac_usage s)
let mac_key p i l s = b:bytes{is_mac_key p i b l s}

val mac: #p:global_usage -> #i:nat -> #l:label -> #l':label ->
    k:lbytes p i l{is_publishable p i k \/ (exists s. is_mac_key p i k l s)} ->
    m:msg p i l'{forall s. is_mac_key p i k l s ==> mac_pred p.usage_preds i k m} -> msg p i l'

val mac_lemma: #p:global_usage -> #i:nat -> #l:label -> #l':label ->
    k:lbytes p i l{is_publishable p i k \/ (exists s. is_mac_key p i k l s)} ->
    m:msg p i l'{forall s. is_mac_key p i k l s ==> mac_pred p.usage_preds i k m} ->
    Lemma (mac k m == C.mac k m)
    [SMTPat (mac k m)]

val hash: #p:global_usage -> #i:nat -> #l:label -> m:msg p i l -> msg p i l
val hash_lemma: #p:global_usage -> #i:nat -> #l:label -> m:msg p i l ->
  Lemma (ensures (hash m == C.hash m))
	[SMTPat (hash m)]

let is_kdf_key p i b l s = is_secret p i b l (kdf_usage s)
let kdf_key p i l s = b:bytes{is_kdf_key p i b l s}

val extract: #p:global_usage -> #i:nat -> #l:label -> #l':label ->
    k:lbytes p i l{is_publishable p i k \/ (exists s. is_kdf_key p i k l s)} ->
    salt:lbytes p i l' ->
    k':bytes{((is_publishable p i k /\ is_publishable p i salt) ==> is_publishable p i k') /\
              (forall s. is_kdf_key p i k l s ==> (is_labeled p i k' (join (meet l l') (p.key_usages.kdf_extend_label s k salt)) /\
					      get_usage p.key_usages k' == p.key_usages.kdf_extract_usage s k salt))}

val extract_lemma: #p:global_usage -> #i:nat -> #l:label -> #l':label ->
    k:lbytes p i l{is_publishable p i k \/ (exists s. is_kdf_key p i k l s)} -> salt:lbytes p i l' ->
    Lemma (extract #p #i #l k salt == C.extract k salt) [SMTPat (extract #p #i #l k salt)]

val expand: #p:global_usage -> #i:nat -> #l:label ->
    k:lbytes p i l{is_publishable p i k \/ (exists s. is_kdf_key p i k l s)} ->
    info:msg p i public ->
    k':lbytes p i l{(is_publishable p i k ==> is_publishable p i k') /\
  		    (forall s. is_kdf_key p i k l s ==> (is_labeled p i k' l /\ get_usage p.key_usages k' == p.key_usages.kdf_expand_usage s k info))}

val expand_lemma: #p:global_usage -> #i:nat -> #l:label -> k:lbytes p i l{is_publishable p i k \/ (exists s. is_kdf_key p i k l s)} -> info:msg p i public ->
    Lemma (expand #p #i #l k info == C.expand k info) [SMTPat (expand #p #i #l k info)]

let is_dh_private_key p i b l s = is_secret p i b l (dh_usage s)
let is_dh_public_key p i b l s = is_publishable p i b /\ (exists sk. is_secret p i sk l (dh_usage s) /\ b == dh_pk sk)
type dh_private_key p (i:nat) (l:label) s = b:bytes{is_dh_private_key p i b l s}
type dh_public_key p (i:nat) (l:label) s = b:bytes{is_dh_public_key p i b l s}

val dh_pk: #p:global_usage -> #i:nat -> #l:label -> sk:lbytes p i l -> lbytes p i public
val dh_pk_lemma: #p:global_usage -> #i:nat -> #l:label -> sk:lbytes p i l ->
  Lemma (ensures (dh_pk #p #i #l sk == C.dh_pk sk /\
		  (forall s. is_dh_private_key p i sk l s <==> is_dh_public_key p i (dh_pk #p #i #l sk) l s)))
        [SMTPat (dh_pk #p #i #l sk)]
val dh_key_label_lemma : p:global_usage -> i:nat -> b:bytes -> Lemma (forall s l. is_dh_public_key p i b l s ==> get_dhkey_label p.key_usages b == l)

val dh: #p:global_usage -> #i:nat -> #l:label -> 
	sk:lbytes p i l{is_publishable p i sk \/ (exists s. is_dh_private_key p i sk l s)} -> 
	pk:msg p i public ->
	k:lbytes p i (join l (get_dhkey_label p.key_usages pk)){
		(is_publishable p i sk ==> is_publishable p i k) /\ // can be derived from type of k
		(forall s s' l'. (is_dh_private_key p i sk l s /\ is_dh_public_key p i pk l' s') ==>
			    get_usage p.key_usages k == p.key_usages.dh_shared_secret_usage s s' k) /\
		(forall s. (is_dh_private_key p i sk l s /\ p.key_usages.dh_unknown_peer_usage s k =!= None) ==>
		   	    get_usage p.key_usages k == p.key_usages.dh_unknown_peer_usage s k)}
val dh_lemma: #p:global_usage -> #i:nat -> #l:label -> 
	      sk:lbytes p i l{is_publishable p i sk \/ (exists s. is_dh_private_key p i sk l s)} -> pk:msg p i public -> 
	      Lemma (dh #p #i #l sk pk == C.dh sk pk)
	      [SMTPat (dh sk pk)]

(**
  Lemmas stating that bytes are publishable.
*)
val literals_are_publishable_forall : p:global_usage -> Lemma (forall i (s:C.literal). is_publishable p i (C.literal_to_bytes s))
val splittable_term_publishable_implies_components_publishable_forall: p:global_usage ->
    Lemma (forall i t t_part1 t_part2. (is_succ2 (C.split t) t_part1 t_part2 /\ is_publishable p i t) ==>
				  (is_publishable p i t_part1 /\ is_publishable p i t_part2))
val concatenation_publishable_implies_components_publishable_forall : p:global_usage ->
    Lemma (forall i t1 t2. (is_publishable p i (C.concat t1 t2)) ==> (is_publishable p i t1 /\ is_publishable p i t2))
val public_key_is_publishable_if_private_key_is_publishable_forall : p:global_usage ->
    Lemma (forall i t. is_publishable p i t  ==> is_publishable p i (C.pk t))
val pke_ciphertext_publishable_if_key_and_msg_are_publishable_forall: p:global_usage ->
    Lemma (forall i pub_key msg. (is_publishable p i pub_key /\ is_publishable p i msg) ==> (is_publishable p i (C.pke_enc pub_key msg)))
val pke_plaintext_publishable_if_key_and_ciphertext_publishable_forall: p:global_usage ->
  Lemma (forall i priv_key ciphertext plaintext. (is_succ (C.pke_dec priv_key ciphertext) plaintext /\ is_publishable p i priv_key /\ 
					    is_publishable p i ciphertext) ==> is_publishable p i plaintext)
val aead_enc_ciphertext_publishable_if_key_and_msg_are_publishable_forall: p:global_usage ->
    Lemma (forall i key msg ad. (is_publishable p i key /\ is_publishable p i msg /\ is_publishable p i ad) ==>
			   (is_publishable p i (C.aead_enc key msg ad)))
val aead_dec_plaintext_publishable_if_key_and_ciphertext_publishable_forall: p:global_usage ->
  Lemma (forall i key ciphertext plaintext ad. (is_succ (C.aead_dec key ciphertext ad) plaintext /\ is_publishable p i key /\ 
					  is_publishable p i ciphertext /\ is_publishable p i ad) ==> is_publishable p i plaintext)
val verif_key_is_publishable_if_private_key_is_publishable_forall : p:global_usage ->
    Lemma (forall i t. is_publishable p i t  ==> is_publishable p i (C.vk t))
val sig_is_publishable_if_key_and_msg_are_publishable_forall: p:global_usage ->
    Lemma (forall i t1 t2. (is_publishable p i t1 /\ is_publishable p i t2) ==> is_publishable p i (C.sign t1 t2))
val mac_is_publishable_if_key_and_msg_are_publishable_forall: p:global_usage ->
    Lemma (forall i t1 t2. (is_publishable p i t1 /\ is_publishable p i t2) ==> is_publishable p i (C.mac t1 t2))
val expand_value_publishable_if_secrets_are_publishable_forall: p:global_usage ->
    Lemma (forall i t1 t2. (is_publishable p i t1 /\ is_publishable p i t2) ==> is_publishable p i (C.expand t1 t2))
val extract_value_publishable_if_secrets_are_publishable_forall: p:global_usage ->
    Lemma (forall i t1 t2. (is_publishable p i t1 /\ is_publishable p i t2) ==> is_publishable p i (C.extract t1 t2))
val hash_value_publishable_if_message_is_publishable_forall: p:global_usage ->
    Lemma (forall i t1. (is_publishable p i t1) ==> is_publishable p i (C.hash t1))
val dh_public_key_is_publishable_if_private_key_is_publishable_forall : p:global_usage ->
    Lemma (forall i t. is_publishable p i t  ==> is_publishable p i (C.dh_pk t))
val dh_is_publishable_if_keys_are_publishable_forall: p:global_usage ->
    Lemma (forall i t1 t2. (is_publishable p i t1 /\ is_publishable p i t2) ==> is_publishable p i (C.dh t1 (C.dh_pk t2)))
