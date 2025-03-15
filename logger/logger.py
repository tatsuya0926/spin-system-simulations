import logging
import datetime


def init_logger(
    outdir='', tag='', level_console='warning', level_file='info'):
    """log出力の設定
    Args:
        module_name (str): 対象とするモジュール名, __name__.
        outdir (str, optional): 出力先ディレクトリ名. Defaults to ''.
        tag (str, optional): 出力ファイル名. Defaults to ''.
        level_console (str, optional): loggingのレベルを指定. Defaults to 'warning'.
        level_file (str, optional): loggingのレベルをstrで指定. Defaults to 'info'.

    Returns:
        str: log
    """
    level_dic = {
        'critical': logging.CRITICAL,
        'error': logging.ERROR,
        'warning': logging.WARNING,
        'info': logging.INFO,
        'debug': logging.DEBUG,
        'notset': logging.NOTSET
    }
    if len(tag)==0:
        tag = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    logging.basicConfig(
        format='[%(asctime)s] [%(levelname)s] %(message)s',
        filename=f'{outdir}/{tag}.log',
        level=level_dic[level_file],
        datefmt='%Y%m%d-%H%M%S',
    )
    
    logger = logging.getLogger()
    sh = logging.StreamHandler()
    sh.setLevel(level_dic[level_console])
    fmt = logging.Formatter(
        "[%(asctime)s] [%(levelname)s] %(message)s",
        "%Y%m%d-%H%M%S"
        )
    sh.setFormatter(fmt)
    logger.addHandler(sh)
    
    return logger