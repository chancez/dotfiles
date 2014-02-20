# Store VMS on localdisk if at work
if [[ `hostname -f` == *osuosl* && `hostname` != "ash" ]] ; then
    vboxmanage setproperty machinefolder "/data/virtualbox-vms/$USER/vbox/"
    local vm_base_path="/data/virtualbox-vms/$USER"
    if [[ ! -e $vm_base_path ]]; then
        mkdir -p $vm_base_path
    fi
    export VAGRANT_HOME="$vm_base_path/vagrant"
fi

function fsh () {
        ssh -t fir "sudo bash -i -c \"ssh $@\""
}
