# R server in singularity

This workflow together with the script `singRstudio.sh` facilitates setting up an R server running in a singularity container on a HPC and accessing it on a local PC.

# Workflow

## Prepare (only first time)

### On local PC

Since building a singularity image requires root privilege it is often not possible to directly build on your HPC. A simple workaround is to build in on your local PC and the copy to the server.
Build Singularity image file:
```
sudo singularity build singularity_container.sif Singularity_bioc_python
```
The given Singularity build file is just an example, to customize for your needs have a look at the [singularity documentation](https://sylabs.io/guides/3.5/user-guide/build_a_container.html).

After building the image copy to server, e.g.
```
scp singularity_container.sif SERVERNAME:/some/location
```

Alternatively there is the possibily to build without sudo using the `--remote` flage. [Singularity documentation](https://sylabs.io/guides/3.5/user-guide/cloud_library.html)

## Setup 

### On server

Make sure a suitable temporary directory is available, e.g. `~/tmp` (the default).

Decide on the port you want to use, the default is 8788.

Run rserver with singularity:
```
bash singRstudio.sh -c singularity_container.sif -t ~/tmp -p 8789
```

### On local PC

Redirect traffic from port on server to local port via ssh:
```
ssh -Nf -L LOCALPORT:localhost:SERVERPORT SERVERNAME
```
replacing `LOCALPORT` with the port you want to use on your local pc, `SERVERPORT` with the above specified port (default 8788) and `SERVERNAME` with the address of the server.
e.g:
```
ssh -Nf -L 8787:localhost:8788 user@myserver.com
```

Then open a browser and go to `http://localhost:LOCALPORT` again replacing `LOCALPORT`. Login with your server username and passwort (as specified with the `-a` argument, default: `password`).

## Other options:

### Bind local directories to container

To connect directories to the container in a specific manner set the `-b` argument:
```
bash singRstudio.sh -c singularity_container.sif -b "local/dir/1:/absolute/container/dir/1,local/dir/2:/absolute/container/dir/2"
```

### local R library

Since singularity containers are read-only, installing R packages is not possible. For reproducibility this is great as it is always clear what packages were used,
but sometimes it can be a nuissance when testing stuff. A workaround is to specify a local directory in which the packages are installed. This can be done setting
the `-r` argument:
```
bash singRstudio.sh -c singularity_container.sif -r ~/my/R/library
```

### Dry run
To just show the "built" singularity command without executing it add `-d`:
```
bash singRstudio.sh -c singularity_container.sif -d
```
