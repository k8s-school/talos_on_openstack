
if [ -f ~/.novacreds/fink-openrc.sh ]; then
    . ~/.novacreds/fink-openrc.sh
else
    echo "No OpenStack credentials found. Please source the appropriate openrc file."
fi

if [ -f ~/openstack_cli/bin/activate ]; then
    . ~/openstack_cli/bin/activate
fi

export PATH=$PWD/bin:$PATH
