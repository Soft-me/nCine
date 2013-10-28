#include "ncThreadSync.h"
#include "ncServiceLocator.h"

///////////////////////////////////////////////////////////
// ncMutex CLASS
///////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////
// CONSTRUCTORS and DESTRUCTOR
///////////////////////////////////////////////////////////

ncMutex::ncMutex()
{
	pthread_mutex_init(&m_mutex, NULL);
}

ncMutex::~ncMutex()
{
	pthread_mutex_destroy(&m_mutex);
}

///////////////////////////////////////////////////////////
// PUBLIC FUNCTIONS
///////////////////////////////////////////////////////////

void ncMutex::Lock()
{
	pthread_mutex_lock(&m_mutex);
}

void ncMutex::Unlock()
{
	pthread_mutex_unlock(&m_mutex);
}

int ncMutex::TryLock()
{
	return pthread_mutex_trylock(&m_mutex);
}


///////////////////////////////////////////////////////////
// ncCondVariable CLASS
///////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////
// CONSTRUCTORS and DESTRUCTOR
///////////////////////////////////////////////////////////

ncCondVariable::ncCondVariable()
{
	pthread_cond_init(&m_cond, NULL);
}

ncCondVariable::~ncCondVariable()
{
	pthread_cond_destroy(&m_cond);
}

///////////////////////////////////////////////////////////
// PUBLIC FUNCTIONS
///////////////////////////////////////////////////////////

void ncCondVariable::Wait(ncMutex &rMutex)
{
	pthread_cond_wait(&m_cond, &(rMutex.m_mutex));
}

void ncCondVariable::Signal()
{
	 pthread_cond_signal(&m_cond);
}

void ncCondVariable::Broadcast()
{
	pthread_cond_broadcast(&m_cond);
}