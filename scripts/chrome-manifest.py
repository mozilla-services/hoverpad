import os
import json
import codecs

here = os.path.dirname(os.path.abspath(os.path.dirname(__file__)))
filename = "manifest.json"

input_file = os.path.join(here, filename)
output_file = os.path.join(here, 'www/', filename)

with codecs.open(input_file, encoding='utf-8') as f:
    print("Reading {}".format(input_file))
    data = json.load(f)

del data['applications']

with codecs.open(output_file, 'w', encoding='utf-8') as f:
    print("Writting {}".format(output_file))
    json.dump(data, f)
