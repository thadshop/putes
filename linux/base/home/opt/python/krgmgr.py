import keyring, keyring.util.platform_, sagecipher
from sagecipher.keyring import Keyring
import configparser
from pathlib import Path
import sys
import collections
import getpass
import subprocess

keyring.set_keyring(sagecipher.keyring.Keyring())
krg_filename  =  f"{keyring.util.platform_.data_root()}/{keyring.get_keyring().filename}"

Choice  =  collections.namedtuple('Choices', ['desc', 'exec'])

global krg_dict, krg_idx

def list_krg_file():
    try:
        print('\n' + subprocess.check_output(['ls', '-l', krg_filename]).decode('utf-8'))
    except subprocess.CalledProcessError:
        pass
    return

def refresh_krg_dict_idx():
    global krg_dict, krg_idx
    krg_dict  =  {}
    krg_idx  =  {}
    krg_cfg  =  configparser.ConfigParser()
    if Path(krg_filename).is_file():
        krg_cfg.read(krg_filename)
        krg_encodeddict  =  {section: dict(krg_cfg.items(section)) for section in krg_cfg.sections()}
        def decode_key(key):
            decoded  =  ''
            i  =  0
            while(i < len(key)):
                if (key[i] == '_'):
                    decoded  =  decoded + bytes.fromhex(key[i+1:i+3]).decode()
                    i += 3
                else:
                    decoded  =  decoded + key[i]
                    i += 1
            return decoded
        is_svc_removed  =  False
        idx  =  0
        for svc_encodedkey in krg_encodeddict.keys():
            svc_key  =  decode_key(svc_encodedkey)
            svc_dict  =  {}
            for user_encodedkey in krg_encodeddict[svc_encodedkey].keys():
                user_key  =  decode_key(user_encodedkey)
                passwd_encoded  =  krg_encodeddict[svc_encodedkey][user_encodedkey]
                svc_dict[user_key]  =  passwd_encoded
                idx += 1
                krg_idx[str(idx)]  =  (svc_key, user_key)
            if svc_dict:
                krg_dict[svc_key]  =  svc_dict
            else:
                krg_cfg.remove_section(svc_encodedkey)
                is_svc_removed  =  True
        if is_svc_removed:
            with open(krg_filename, 'w') as krg_file:
                krg_cfg.write(krg_file)
            refresh_krg_dict_idx()
    else:
        print('INFO: keyring file "{}" does not exist'.format(krg_filename))
    return

def list_krg_idx():
    global krg_idx
    col_sep  =  '   '
    col2_wid  =  5
    col3_wid  =  6
    for idx in krg_idx:
        (svc, user)  =  krg_idx[idx]
        if len(svc) > col2_wid:
            col2_wid  =  len(svc)
        if len(user) > col3_wid:
            col3_wid  =  len(user)
    print('\n[idx]\t{}{}[user]'.format('[svc]'.ljust(col2_wid), col_sep))
    print('-----\t{}{}{}'.format('-'.ljust(col2_wid, '-'), col_sep, '-'.ljust(col3_wid, '-')))
    for idx in krg_idx:
        (svc, user)  =  krg_idx[idx]
        print('{}\t{}{}{}'.format(idx, svc.ljust(col2_wid), col_sep, user))
    print()
    return

def menu(title = '', choices = {}, default = '', is_choice_main = True, is_choice_exit = True):
    prompt_default  =  ''
    if not 'm' in choices.keys() and is_choice_main:
        choices['m']  =  Choice(desc = 'go to main menu', exec = 'main()')
    if not 'x' in choices.keys() and is_choice_exit:
        choices['x']  =  Choice(desc = 'exit', exec = 'do_exit()')
    if default:
        if default not in choices.keys():
            print('ERROR: internal configuration fault: default value "{}" is not in choice keys "{}"'.format(default, choices), file = sys.stderr)
            sys.exit(1)
        else:
            prompt_default  =  '[{}]'.format(default)
    while True:
        print()
        if title:
            print(title)
        for key in choices.keys():
            print(' {}\t{}'.format(key, choices[key].desc))
        try:
            sel = input('enter selection:{} '.format(prompt_default))
        except EOFError:
            print('\n\nplease make a selection')
            continue
        if sel:
            if sel in choices.keys():
                exec(choices[sel].exec)
                break
            else:
                print('invalid selection')
        else:
            if default:
                exec(choices[default].exec)
                break
            else:
                print('\nplease make a selection')
    return

def get_input(prompt, allow_empty = False, valid_list = [], exec_on_int = 'main()', is_passwd  =  False):
    got  =  ''
    while True:
        try:
            if is_passwd:
                got  =  getpass.getpass(prompt)
            else:
                got  =  input(prompt)
            if got:
                if valid_list:
                    if got in valid_list:
                        break
                    else:
                        print('invalid input; valid values: {}'.format(list(valid_list)))
                else:
                    break
            elif allow_empty:
                break
            else:
                print('empty input is not allowed')
        except EOFError:
            if allow_empty:
                break
            else:
                print('empty input is not allowed')
        except KeyboardInterrupt:
            if exec_on_int:
                exec(exec_on_int)
            else:
                raise KeyboardInterrupt
            break
    return got

def do_exit():
    print('goodbye')
    sys.exit()

def add_cred():
    global krg_dict
    print('adding new credential...')
    print('to return to the main menu, signal interrupt (e.g., <ctrl>+c)')
    svc  =  get_input(prompt = 'service name : ')
    user  =  get_input(prompt = 'user name : ')
    if svc in krg_dict.keys():
        if user in krg_dict[svc].keys():
            menu(
                title = 'credential with that service and user name already exists',
                choices = {'u': Choice(desc = 'update password', exec = 'pass')}
            )
    passwd = get_input(prompt='password: ', is_passwd=True)
    keyring.set_password(svc, user, passwd)
    print('\ncredential added')
    return

def get_cred_keys_by_idx(prompt_action):
    global krg_idx
    list_krg_idx()
    print('to return to the main menu, signal interrupt (e.g., <ctrl>+c)')
    idx = get_input(prompt='enter idx for credential to {}: '.format(prompt_action), valid_list=list(krg_idx.keys()))
    return krg_idx[idx]

def show_enc_passwd(svc, user):
    global krg_dict
    rep_passwd = repr(krg_dict[svc][user])
    print('\n"{}" (without the quotes) is the encrypted password for {}/{}\n'.format(rep_passwd[1:len(rep_passwd) -1], svc, user))
    return

def show_passwd():
    (svc, user) = get_cred_keys_by_idx('show')
    try:
        print('\n"{}" (without the quotes) is the password for {}/{}\n'.format(keyring.get_password(svc, user), svc, user))
        menu(
            choices = {'e': Choice(
                desc = 'show encrypted password',
                exec = "show_enc_passwd('{}', '{}')".format(svc, user)
            )},
            default = 'm'
        )
    except sagecipher.cipher.SshAgentKeyError:
        print('\nunable to decipher password (was it encrypted by a different identity?)\n')
    return

def update_cred():
    (svc, user) = get_cred_keys_by_idx('update the password')
    passwd = get_input(prompt='enter new password for {}/{}: '.format(svc, user), is_passwd=True)
    keyring.set_password(svc, user, passwd)
    print('\npassword for {}/{} updated'.format(svc, user))
    return

def delete_cred():
    (svc, user) = get_cred_keys_by_idx('delete')
    keyring.delete_password(svc, user)
    print('\ncredential {}/{} deleted'.format(svc, user))
    return

def main():
    global krg_dict
    while True:
        refresh_krg_dict_idx()
        choices = {}
        choices['a'] = Choice(desc='add credential', exec='add_cred()')
        if not krg_dict:
            print('INFO: keyring is empty')
        else:
            choices['l'] = Choice(desc='list credentials', exec='list_krg_idx()')
            choices['u'] = Choice(desc="update a credential's password", exec='update_cred()')
            choices['d'] = Choice(desc='delete a credential', exec='delete_cred()')
            choices['s'] = Choice(desc="show a credential's password", exec='show_passwd()')
        choices['f'] = Choice(desc='list keyring file', exec='list_krg_file()')
        menu('MAIN MENU', choices=choices, default='x', is_choice_main=False)

if __name__ == '__main__':
    sys.exit(main())
