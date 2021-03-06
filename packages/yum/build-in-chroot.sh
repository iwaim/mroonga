#!/bin/sh

if [ $# != 10 ]; then
    echo "Usage: $0 PACKAGE VERSION SOURCE_BASE_NAME SPEC_DIR CHROOT_BASE ARCHITECTURES DISTRIBUTIONS HAVE_DEVELOPMENT_BRANCH USE_RPMFORGE USE_ATRPMS"
    echo " e.g.: $0 milter-manager 1.1.1 ../milter-manager ../rpm /var/lib/chroot 'i386 x86_64' 'fedora centos' yes no no"
    exit 1
fi

PACKAGE=$1
VERSION=$2
SOURCE_BASE_NAME=$3
SPEC_DIR=$4
CHROOT_BASE=$5
ARCHITECTURES=$6
DISTRIBUTIONS=$7
HAVE_DEVELOPMENT_BRANCH=$8
USE_RPMFORGE=$9
USE_ATRPMS=$10

PATH=/usr/local/sbin:/usr/sbin:$PATH

script_base_dir=`dirname $0`

if test "$PARALLEL" = "yes"; then
    parallel="yes"
else
    parallel="no"
fi

run()
{
    "$@"
    if test $? -ne 0; then
	echo "Failed $@"
	exit 1
    fi
}

run_sudo()
{
    run sudo "$@"
}

build_chroot()
{
    architecture=$1
    distribution_name=$2
    distribution_version=$3

    if [ $architecture = "x86_64" ]; then
	rinse_architecture="amd64"
        distribution_architecture=$architecture
    else
	rinse_architecture=$architecture
	if [ "$distribution_name-$distribution_version" = "centos-5" ]; then
	    distribution_architecture=$architecture
	else
	    distribution_architecture=i686
	fi
    fi
    if [ "$distribution_name-$distribution_version" = "fedora-16" ]; then
	rinse_distribution_version="15"
    else
	rinse_distribution_version="$distribution_version"
    fi

    run_sudo mkdir -p ${base_dir}/etc/rpm
    rpm_platform=${distribution_architecture}-${distribution}-linux
    run_sudo sh -c "echo ${rpm_platform} > ${base_dir}/etc/rpm/platform"
    run_sudo rinse \
	--arch $rinse_architecture \
	--distribution $distribution_name-$rinse_distribution_version \
	--directory $base_dir
    run_sudo rinse --arch $rinse_architecture --clean-cache

    run_sudo sh -c "echo >> /etc/fstab"
    run_sudo sh -c "echo /dev ${base_dir}/dev none bind 0 0 >> /etc/fstab"
    run_sudo sh -c "echo devpts-chroot ${base_dir}/dev/pts devpts defaults 0 0 >> /etc/fstab"
    run_sudo sh -c "echo proc-chroot ${base_dir}/proc proc defaults 0 0 >> /etc/fstab"
    run_sudo mount ${base_dir}/dev
    run_sudo mount ${base_dir}/dev/pts
    run_sudo mount ${base_dir}/proc

    if [ "$distribution_name-$distribution_version" = "fedora-16" ]; then
	yes | run_sudo su -c "chroot ${base_dir} rpm --import https://fedoraproject.org/static/A82BA4B7.txt"
	run_sudo su -c "chroot ${base_dir} yum -y update yum"
	run_sudo su -c "chroot ${base_dir} yum -y clean all"
	run_sudo su -c "chroot ${base_dir} yum -y --releasever=16 --disableplugin=presto distro-sync"
    fi
}

build()
{
    architecture=$1
    distribution=$2
    distribution_version=$3

    target=${distribution}-${distribution_version}-${architecture}
    base_dir=${CHROOT_BASE}/${target}
    if [ ! -d $base_dir ]; then
	run build_chroot $architecture $distribution $distribution_version
    fi

    build_user=${PACKAGE}-build
    build_user_dir=${base_dir}/home/${build_user}
    rpm_base_dir=${build_user_dir}/rpm
    rpm_dir=${rpm_base_dir}/RPMS/${architecture}
    srpm_dir=${rpm_base_dir}/SRPMS
    pool_base_dir=${distribution}/${distribution_version}
    if test "${HAVE_DEVELOPMENT_BRANCH}" = "yes"; then
	minor_version=$(echo $VERSION | ruby -pe '$_.gsub!(/\A\d+\.(\d+)\..*/, "\\1")')
	if test $(expr ${minor_version} % 2) -eq 0; then
	    branch_name=stable
	else
	    branch_name=development
	fi
	pool_base_dir=${pool_base_dir}/${branch_name}
    fi
    binary_pool_dir=$pool_base_dir/$architecture/Packages
    source_pool_dir=$pool_base_dir/source/SRPMS
    if test -f ${SOURCE_BASE_NAME}-${VERSION}-*.src.rpm; then
	run cp ${SOURCE_BASE_NAME}-${VERSION}-*.src.rpm \
	    ${CHROOT_BASE}/$target/tmp/
    else
	run cp ${SOURCE_BASE_NAME}-${VERSION}.* \
	    ${CHROOT_BASE}/$target/tmp/
	run cp ${SPEC_DIR}/${distribution}/${PACKAGE}.spec \
	    ${CHROOT_BASE}/$target/tmp/
    fi
    run echo $PACKAGE > ${CHROOT_BASE}/$target/tmp/build-package
    run echo $VERSION > ${CHROOT_BASE}/$target/tmp/build-version
    run echo $(basename ${SOURCE_BASE_NAME}) > \
	${CHROOT_BASE}/$target/tmp/build-source-base-name
    run echo $build_user > ${CHROOT_BASE}/$target/tmp/build-user
    run cp ${script_base_dir}/${PACKAGE}-depended-packages \
	${CHROOT_BASE}/$target/tmp/depended-packages
    run echo $USE_RPMFORGE > ${CHROOT_BASE}/$target/tmp/build-use-rpmforge
    run echo $USE_ATRPMS > ${CHROOT_BASE}/$target/tmp/build-use-atrpms
    run cp ${script_base_dir}/${PACKAGE}-build-options \
	${CHROOT_BASE}/$target/tmp/build-options
    run cp ${script_base_dir}/build-rpm.sh ${CHROOT_BASE}/$target/tmp/
    run_sudo su -c "chroot ${CHROOT_BASE}/$target /tmp/build-rpm.sh"
    run mkdir -p $binary_pool_dir
    run mkdir -p $source_pool_dir
    run cp -p $rpm_dir/*-${VERSION}* $binary_pool_dir
    run cp -p $srpm_dir/*-${VERSION}* $source_pool_dir
    if [ $distribution = "centos" -a $distribution_version -eq 5 ]; then
	mysql_version=$(grep '%define mysql_version' \
	    ${CHROOT_BASE}/$target/tmp/${PACKAGE}.spec | \
	    sed -e 's/%define mysql_version //g' | \
	    tail -1)
	run cp -p $rpm_dir/MySQL-*-${mysql_version}* $binary_pool_dir
	run cp -p $srpm_dir/MySQL-${mysql_version}* $source_pool_dir
    fi

    dependencies_dir=${build_user_dir}/dependencies
    dependencies_rpm_dir=${dependencies_dir}/RPMS
    dependencies_srpm_dir=${dependencies_dir}/SRPMS
    if [ -d "${dependencies_rpm_dir}" ]; then
	run cp -p ${dependencies_rpm_dir}/* $binary_pool_dir
    fi
    if [ -d "${dependencies_srpm_dir}" ]; then
	run cp -p ${dependencies_srpm_dir}/* $source_pool_dir
    fi
}

for architecture in $ARCHITECTURES; do
    for distribution in $DISTRIBUTIONS; do
	case $distribution in
	    fedora)
		distribution_versions="16"
		;;
	    centos)
		distribution_versions="5 6"
		;;
	esac
	for distribution_version in $distribution_versions; do
	    if test "$parallel" = "yes"; then
		build $architecture $distribution $distribution_version &
	    else
		build $architecture $distribution $distribution_version
	    fi;
	done;
    done;
done

if test "$parallel" = "yes"; then
    wait
fi
